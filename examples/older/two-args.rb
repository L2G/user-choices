### The following adjusts the load path so that the correct version of
### a self-contained package is found, no matter where the script is
### run from. 
require 'pathname'
$:.unshift((Pathname.new(__FILE__).parent.parent + 'lib').to_s)
require 's4t-utils/load-path-auto-adjuster'


require 'pp'
require 'user-choices'

class TwoArgExample < UserChoices::Command

  def add_sources(builder)
    builder.add_source(UserChoices::CommandLineSource, :usage,
                       "Usage: ruby #{$0} [options] infile outfile")
    
  end

  def add_choices(builder)
    # You can specify an exact number of array elements required.
    builder.add_choice(:args, :length => 2) { | command_line |
      command_line.uses_arglist
    }
  end

  def execute
    pp @user_choices
  end
end


if $0 == __FILE__
  S4tUtils.with_pleasant_exceptions do
    TwoArgExample.new.execute
  end
end
