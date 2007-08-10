#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

require 'user-choices/ruby-extensions'

module UserChoices
  class ArglistStrategy
    def initialize(value_holder, choice=nil)
      @value_holder = value_holder
      @choice = choice
    end
    
    def update_from_arglist(arglist); subclass_responsibility; end
    def adapt_to_global_constraints(all_choices, conversions)
      # By default, do nothing.
    end

    
    def add_error_message_maker(makers)
      friendlier_length_error = lambda {| choice, conversion |
        arglist_arity_error(@value_holder[choice].length, conversion.required_length)
      }
      makers[@choice] = friendlier_length_error if @choice
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
    
  end
  
  class NoArguments < ArglistStrategy      
    def update_from_arglist(arglist)
      user_claims(arglist.length == 0) do
        "No arguments are allowed."
      end
    end
  end
  
  class ArbitraryArglist < ArglistStrategy
    def update_from_arglist(arglist)
      @value_holder[@choice] = arglist unless arglist.empty?
    end
    
    def adapt_to_global_constraints(all_choices, conversions)
      return if @value_holder[@choice]
      return if all_choices.has_key?(@choice)
      
      all_choices[@choice] = []
      @value_holder[@choice] = all_choices[@choice]
      @value_holder.apply(@choice => conversions[@choice])
    end
  end
  
  class NonListStrategy < ArglistStrategy
    def arity; subclass_responsibility; end
    
    def update_from_arglist(arglist)
      case arglist.length
      when 0: # This is not considered an error because another source
              # might fill in the value.
      when 1: @value_holder[@choice] = arglist[0]
      else user_is_bewildered(arglist_arity_error(arglist.length, self.arity))
      end
    end
    

  end
    
  
  class OneRequiredArg < NonListStrategy
    def arity; 1; end
    
    def adapt_to_global_constraints(all_choices, conversions)
      return if @value_holder[@choice]
      return if all_choices.has_key?(@choice)

      @value_holder[@choice] = []
      @value_holder.apply(@choice => [Conversion.for(:length => 1)])
    end
      
  end
  
  class OneOptionalArg < NonListStrategy
    def arity; 0..1; end
  end

end