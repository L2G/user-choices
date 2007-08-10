### The following adjusts the load path so that the correct version of
### a self-contained package is found, no matter where the script is
### run from. 
require 'pathname'
$:.unshift((Pathname.new(__FILE__).parent.parent + 'lib').to_s)
require 's4t-utils/load-path-auto-adjuster'

require 'pp'
require 'user-choices'

class TutorialExample < UserChoices::Command
  include UserChoices

  def add_sources(builder)
    builder.add_source(CommandLineChoices, :usage,
                       "Usage: ruby #{$0} infile outfile")
  end

  def add_choices(builder)
    builder.add_choice(:files, :length => 2) { | command_line | 
      command_line.uses_arglist
    }
  end
  
  def postprocess_user_choices
    @user_choices[:infile] = @user_choices[:files][0]
    @user_choices[:outfile] = @user_choices[:files][1]
  end
  

  def execute
    pp @user_choices
  end
end


if $0 == __FILE__
  S4tUtils.with_pleasant_exceptions do
    TutorialExample.new.execute
  end
end
