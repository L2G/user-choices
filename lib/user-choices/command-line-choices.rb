require 'optparse'
require 's4t-utils'
include S4tUtils

module UserChoices # :nodoc

  # Treat the command line (including the arguments) as a source
  # of choices.
  class CommandLineChoices < ExternallyFilledHash
    def initialize(*args)
      super(*args)
      @parser = OptionParser.new
      @arglist_handler = lambda { | args |
        user_claims(args.length == 0) do
          "No arguments are allowed."
        end
      }
    end
      
    
    # The _usage_lines_ will be used to produce the output from
    # --help (or on error).
    def usage(*usage_lines) 
      help_banner(*usage_lines)
      self
    end
    
    def fill
      exit_upon_error("Error in the command line: ") do
        remainder = @parser.parse(ARGV)
        @arglist_handler.call(remainder)
      end
    end
    
    
    
    def apply(choice_conversions)
      friendlier_length_error = lambda {| choice, conversion |
        if conversion.description.include?("length")
          arglist_arity_error(self[choice].length, conversion.required_length)
        else
          bad_look(choice, conversion)
        end
      }
      
      error_callbacks = {}
      if @arglist_choice_name
        error_callbacks[@arglist_choice_name] = friendlier_length_error
      end

      exit_upon_error do
        super(choice_conversions, error_callbacks)
      end
    end

    def source     # :nodoc: 
      "the command line"
    end

    def help    # :nodoc: 
      $stderr.puts @parser
      exit
    end

    def help_banner(banner, *more)    # :nodoc: 
      @parser.banner = banner
      more.each do | line |
        @parser.separator(line)
      end
      @parser.separator ''
      @parser.separator 'Options:'

      @parser.on_tail("-?", "-h", "--help", "Show this message.") do
        help
      end
    end


    # What we can parse out of the command line

    # Describes how a particular _choice_ is represented on the
    # command line. The _args_ are passed to OptionParser. Each arg
    # will either describe one variant of option (such as <tt>"-s"</tt>
    # or <tt>"--show VALUE"</tt>) or is a line of help text about
    # the option (multiple lines are allowed).
    #
    # If the option takes an array of values, separate the values by commas:
    # --files a,b,c
    # There's currently no way to escape a comma and no cleverness about
    # quotes. 
    def uses_option(choice, *args)
      external_names[choice] = '--' + extract_switch_raw_name(args)
      @parser.on(*args) do | value |
        self[choice] = value
      end
    end

    # A switch is an option that doesn't take a value. A switch
    # described as <tt>"--switch"</tt> has these effects:
    # * If it is not given, the _choice_ is the default value
    #   or is not present in the hash that holds all the choices.
    # * If it is given as <tt>--switch</tt>, the _choice_ has the
    #   value <tt>"true"</tt>. (If the _choice_ was described in
    #   ChoicesBuilder#add_choice as having a <tt>:type => :boolean</tt>,
    #   that value is converted from a string to +true+.)
    # * If it is given as <tt>--no-switch</tt>, the _choice_ has the
    #   value <tt>"false"</tt>.
    def uses_switch(choice, *args)
      external_name = extract_switch_raw_name(args)
      external_names[choice] = '--' + external_name
      args = change_name_to_switch(external_name, args)
      @parser.on(*args) do | value |
        self[choice] = value.to_s
      end
    end


    # Bundle up all non-option and non-switch arguments into an
    # array of strings indexed by _choice_. 
    def uses_arglist(choice)
      external_names[choice] = "the argument list"
      @arglist_handler = lambda { | arglist |
        self[choice] = arglist unless arglist.empty?
      }
      @accepts_argument_list = true
      @arglist_choice_name = choice
    end

    # The single argument required argument is turned into
    # a string indexed by _choice_. Any other case is an error.
    def uses_arg(choice)
      arg_helper(choice, 1)
      @single_required_arg = true
      @arglist_choice_name = choice
    end

    def arg_helper(choice, arity)
      external_names[choice] = "the argument list"
      @arglist_handler = lambda { | arglist |
        case arglist.length
        when 0: # This is not considered an error because another source
                # might fill in the value.
        when 1: self[choice] = arglist[0]
        else user_is_bewildered(arglist_arity_error(arglist.length, arity))
        end
      }
    end

    # If a single argument is present, it (as a string) is the value of
    # _choice_. If no argument is present, _choice_ has no value.
    # Any other case is an error. 
    def uses_optional_arg(choice)
      arg_helper(choice, 0..1)
    end
    
    def accepts_argument_list?
      @accepts_argument_list
    end
    
    def single_required_arg?
      @single_required_arg
    end
    
    def arglist_choice_name
      @arglist_choice_name
    end

    def arglist_arity_error(length, arglist_arity)
      plural = length==1 ? '' : 's'
      expected = case arglist_arity
        when Integer
          arglist_arity.to_s
        when Range
          if arglist_arity.end == arglist_arity.begin.succ
            "#{arglist_arity.begin} or #{arglist_arity.end}"
          else
            arglist_arity.in_words
          end
        else
          arglist_arity.inspect
        end
      "#{length} argument#{plural} given, #{expected} expected."
    end

    def exit_upon_error(prefix = '')
      begin
        yield
      rescue SystemExit
        raise
      rescue Exception => ex
        $stderr.puts(prefix + ex.message)
        help
      end
    end



    private
    
    def extract_switch_raw_name(option_descriptions)
      option_descriptions.each do | desc |
        break $1 if /^--([\w-]+)/ =~ desc
      end
    end

    def change_name_to_switch(name, option_descriptions)
      option_descriptions.collect do | desc |
        /^--/ =~ desc ? "--[no-]#{name}" : desc
      end
    end        
  end


  # Process command-line choices according to POSIX rules. Consider
  #
  # ruby copy.rb file1 --odd-file-name
  #
  # Ordinarily, that's permuted so that --odd-file-name is expected to
  # be an option or switch, not an argument. One way to make
  # CommandLineChoices parsing treat it as an argument is to use a -- to
  # signal the end of option parsing:
  #
  # ruby copy.rb -- file1 --odd-file-name
  #
  # Another is to rely on the user to set environment variable
  # POSIXLY_CORRECT.
  #
  # Since both of those require the user to do something, they're error-prone. 
  #
  # Another way is to use this class, which obeys POSIX-standard rules. Under
  # those rules, the first word on the command line that does not begin with
  # a dash marks the end of all options. In that case, the first command line
  # above would parse into two arguments and no options.
  class PosixCommandLineChoices < CommandLineChoices
    def fill
      begin
        already_set = ENV.include?('POSIXLY_CORRECT')
        ENV['POSIXLY_CORRECT'] = 'true' unless already_set
        super
      ensure
        ENV.delete('POSIXLY_CORRECT') unless already_set
      end
    end
  end
end



