#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-08-10.
#  Copyright (c) 2007. All rights reserved.

require 'user-choices/ruby-extensions'

module UserChoices
  class ArglistStrategy
    
    attr_reader :choice
    
    def initialize(value_holder, choice=nil)
      @value_holder = value_holder
      @choice = choice
    end
    
    def fill(arglist); subclass_responsibility; end
    
    def claim_conversions(conversions); 
      @claimed_conversions = []
      conversions
    end
    
    def apply_claimed_conversions
      # None claimed
    end
      
    def adjust(all_choices)
      # By default, do nothing.
    end

    # public for testing.
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
    

    protected
    
    def claim_length_check(conversions)
      retval = conversions.dup
      @length_check = retval[@choice].find { |c| c.does_length_check? }
      if @length_check
        retval[@choice] = retval[@choice].dup
        retval[@choice].reject { |c| c.does_length_check? }
      end
      retval
    end

    
  end
  
  class NoArguments < ArglistStrategy      
    def fill(arglist)
      user_claims(arglist.length == 0) do
        "No arguments are allowed."
      end
    end
    
  end
  
  class ArbitraryArglist < ArglistStrategy
    def fill(arglist)
      @value_holder[@choice] = arglist unless arglist.empty?
    end
    
    def claim_conversions(conversions)
      claim_length_check(conversions)
    end
    
    def apply_claimed_conversions
      apply_length_check
    end
      
    def adjust(all_choices)
      return if @value_holder[@choice]
      return if all_choices.has_key?(@choice)
      
      all_choices[@choice] = []
      @value_holder[@choice] = all_choices[@choice]
      apply_length_check
    end



    private

    
    def apply_length_check
      return unless @length_check
      return unless @value_holder[@choice]
      
      value = @value_holder[@choice]
      user_claims(@length_check.suitable?(value)) {
        arglist_arity_error(value.length, @length_check.required_length)
      }
    end
    
    
  end
  
  class NonListStrategy < ArglistStrategy
    def arity; subclass_responsibility; end
    
    def fill(arglist)
      case arglist.length
      when 0: # This is not considered an error because another source
              # might fill in the value.
      when 1: @value_holder[@choice] = arglist[0]
      else user_is_bewildered(arglist_arity_error(arglist.length, self.arity))
      end
    end
    
    def claim_conversions(conversions)
      claim_length_check(conversions)
      user_denies(@length_check) {
        "Don't specify the length of an argument list when it's not treated as an array."
      }
      conversions
    end
  end
    
  
  class OneRequiredArg < NonListStrategy
    def arity; 1; end
    
    def adjust(all_choices)
      return if all_choices.has_key?(@choice)

      user_claims(all_choices.has_key?(@choice)) {
        arglist_arity_error(0, 1)
      }
    end
    
  end
  
  class OneOptionalArg < NonListStrategy
    def arity; 0..1; end
  end

end