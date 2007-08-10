require 'optparse'
require 's4t-utils'
include S4tUtils

module UserChoices # :nodoc

  # Treat the command line (including the arguments) as a source
  # of choices.
  class CommandLineSource < ExternallyFilledHash
    class ArglistStrategy
      def initialize(command_line, choice=nil)
        @command_line = command_line
        @choice = choice
        @value = nil
      end
      
      def update(hash, value)
        @value = value
        hash[@choice] = value
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
      
      def add_error_message_maker(makers)
        cmd = @command_line
        friendlier_length_error = lambda {| choice, conversion |
          arglist_arity_error(cmd[choice].length, conversion.required_length)
        }
        makers[@choice] = friendlier_length_error if @choice
      end
      
      
      def handle_first_pass(arglist); subclass_responsibility; end
      def handle_second_pass(all_choices, conversions)
      end
      
    end
    
    class NoArguments < ArglistStrategy      
      def handle_first_pass(arglist)
        user_claims(arglist.length == 0) do
          "No arguments are allowed."
        end
      end
    end
    
    class ArbitraryArglist < ArglistStrategy
      def handle_first_pass(arglist)
        update(@command_line, with = arglist) unless arglist.empty?
      end
      
      def handle_second_pass(all_choices, conversions)
        return if @command_line[@choice]
        return if all_choices.has_key?(@choice)
        
        all_choices[@choice] = []
        @command_line[@choice] = all_choices[@choice]
        @command_line.apply(@choice => conversions[@choice])
      end
    end
    
    class NonListStrategy < ArglistStrategy
      def arity; subclass_responsibility; end
      
      def handle_first_pass(arglist)
        case arglist.length
        when 0: # This is not considered an error because another source
                # might fill in the value.
        when 1: update(@command_line, with = arglist[0])
        else user_is_bewildered(arglist_arity_error(arglist.length, self.arity))
        end
      end
      

    end
      
    
    class OneRequiredArg < NonListStrategy
      def arity; 1; end
      
      def handle_second_pass(all_choices, conversions)
        return if @command_line[@choice]
        return if all_choices.has_key?(@choice)

        @command_line[@choice] = []
        @command_line.apply(@choice => [Conversion.for(:length => 1)])
      end
        
    end
    
    class OneOptionalArg < NonListStrategy
      def arity; 0..1; end
    end



    
    def initialize(*args)
      super(*args)
      @parser = OptionParser.new
      @arglist_handler = NoArguments.new(self)
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
        @arglist_handler.handle_first_pass(remainder)
      end
    end
    
    
    
    def apply(choice_conversions)
      exit_upon_error do
        error_callbacks = {}
        @arglist_handler.add_error_message_maker(error_callbacks)
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

    # The argument list choice probably does not need a name. 
    # (Currently, the name is unused.) But I'll give it one, just 
    # in case, and for debugging.
    ARGLIST = "the argument list"
    
    # Bundle up all non-option and non-switch arguments into an
    # array of strings indexed by _choice_. 
    def uses_arglist(choice)
      external_names[choice] = ARGLIST
      @arglist_handler = ArbitraryArglist.new(self, choice)
    end

    # The single argument required argument is turned into
    # a string indexed by _choice_. Any other case is an error.
    def uses_arg(choice)
      external_names[choice] = ARGLIST
      @arglist_handler = OneRequiredArg.new(self, choice)
    end

    # If a single argument is present, it (as a string) is the value of
    # _choice_. If no argument is present, _choice_ has no value.
    # Any other case is an error. 
    def uses_optional_arg(choice)
      external_names[choice] = ARGLIST
      @arglist_handler = OneOptionalArg.new(self, choice)
    end
    
    def postprocessing_command_line_checks(all_choices, conversions)
      @arglist_handler.handle_second_pass(all_choices, conversions)
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
  # CommandLineSource parsing treat it as an argument is to use a -- to
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
  class PosixCommandLineSource < CommandLineSource
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



