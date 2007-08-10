require 's4t-utils'
include S4tUtils
require 'enumerator'


module UserChoices

  # This class accepts a series of source and choice descriptions
  # and then builds a hash-like object that describes all the choices
  # a user has made before (or while) invoking a script.
  class ChoicesBuilder

    def initialize
      @defaults = {}
      @conversions = {}
      @sources = []
    end
    
    # Add the choice named _choice_, a symbol. _args_ is a keyword
    # argument: 
    # * <tt>:default</tt> takes a *string* value that is the default value of the _choice_. 
    # * <tt>:type</tt> can be given an array of valid string values. These are
    #   checked.
    # * <tt>:type</tt> can also be given <tt>:integer</tt>. The value is cast into
    #   an integer. If that's impossible, an exception is raised. 
    # * <tt>:type</tt> can also be given <tt>:boolean</tt>. The value is converted into
    #   +true+ or +false+ (or an exception is raised).
    # * <tt>:type</tt> can also be given <tt>[:string]</tt>. The value
    #   will be an array of strings. For example, "--value a,b,c" will
    #   produce ['a', 'b', 'c'].
    # 
    # The _block_ is passed a CommandLineChoices object. It's expected
    # to describe the command line.
    def add_choice(choice, args={}, &block)
      # TODO: does the has_key? actually make a difference?
      @defaults[choice] = args[:default] if args.has_key?(:default)
      @conversions[choice] = []
      Conversion.record_for(args[:type], @conversions[choice])
      if args.has_key?(:length)
        Conversion.record_for({:length => args[:length]}, @conversions[choice])
      end
      block.call(ArgForwarder.new(@command_line_source, choice)) if block
    end

    # This adds a source of choices. The _source_ is a class like
    # CommandLineChoices. The _factory_method_ is a class method that's
    # called to create an instance of the class. The _args_ are passed
    # to the _factory_method_. 
    def add_source(source_class, *messages_and_args)
      source = source_class.new
      message_sends(messages_and_args).each { | send_me | source.send(*send_me) }
      @sources << source
      @command_line_source = source if source_class == CommandLineChoices
    end

    # Once sources and choices have been described, this builds and
    # returns a hash-like object indexed by the choices.
    def build
      retval = {}
      @sources << DefaultChoices.new.use_hash(@defaults)
      @sources.each { |s| s.fill }
      @sources.each { |s| s.apply(@conversions) }
      transfer_command_line_info
      @sources.reverse.each { |s| retval.merge!(s) }
      postprocessing_command_line_checks(retval)
      retval
    end
    
    def message_sends(messages_and_args)
      where_at = symbol_indices(messages_and_args)
      where_end = where_at[1..-1] + [messages_and_args.length]
      where_at.to_enum(:each_with_index).collect do |start, where_end_index |
        messages_and_args[start...where_end[where_end_index]]
      end
    end
    
    def symbol_indices(array)
      array.to_enum(:each_with_index).collect do |obj, index|
        index if obj.is_a?(Symbol)
      end.compact
    end
    
    private
    
    # Suppose a command line argument list is to be choice :names. Suppose
    # that the environment contains a variable myprog_names that should be 
    # used if no command line arguments are given. But command line arguments
    # are *always* given - not given means they're the empty list. So this 
    # method makes the default for :names the empty list (unless a default
    # has been explicitly given). If the command line sees an empty list, 
    # it just doesn't set the variable, allowing lower-priority values to 
    # take effect. 
    def transfer_command_line_info
      return unless @command_line_source
      return unless @command_line_source.accepts_argument_list?  # TODO: needed?
      choice = @command_line_source.arglist_choice_name
      @sources.last[choice] = [] unless @sources.last.has_key?(choice)
    end
       
    # If, after all is said and done, a required command-line arg is not
    # given, blame it on the command line (because it has the best error reporting). 
    def postprocessing_command_line_checks(retval)
      return unless @command_line_source
      case 
      when @command_line_source.single_required_arg?
        arg_choice = @command_line_source.arglist_choice_name
        return if retval[arg_choice]
        @command_line_source[arg_choice] = []
        @command_line_source.apply(arg_choice => [Conversion.for(:length => 1)])
      
      when @command_line_source.accepts_argument_list?
        arg_choice = @command_line_source.arglist_choice_name
        @command_line_source[arg_choice] = retval[arg_choice]
        @command_line_source.apply(arg_choice => @conversions[arg_choice])
      end
    end
  

  end

end
