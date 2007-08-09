### The following adjusts the load path so that the correct version of
### a self-contained package is found, no matter where the script is
### run from. 
require 'pathname'
$:.unshift((Pathname.new(__FILE__).parent.parent + 'lib').to_s)
require 's4t-utils/load-path-auto-adjuster'

require 'pp'
require 'user-choices'
include UserChoices

class MultipleSourcesExample < Command

  # Here are the four sources currently available. 
  #
  # EnvironmentChoices is initialized with a prefix. If a choice is
  # named "foo" and the prefix is "ms_", then the value of
  # ENV["ms_foo"] initializes user_choices[:foo].
  #
  # YamlConfigFileChoices reads from a given YAML file. The choices in the
  # config file have the same spelling as the choice name (without the
  # colon that makes the choice name a symbol).
  #
  # XmlConfigFileChoices reads from a given XML file. The choices in the
  # config file have the same spelling as the choice name (without the
  # colon that makes the choice name a symbol).

  def add_sources(builder)
    builder.add_source(CommandLineChoices, :usage,
                       "Usage ruby #{$0} [options] names...")
    builder.add_source(EnvironmentChoices, :with_prefix, "ms_")
    builder.add_source(YamlConfigFileChoices, :from_file, "ms-config.yml")
    builder.add_source(XmlConfigFileChoices, :from_file, "ms-config.xml")
  end

  def add_choices(builder)
    builder.add_choice(:ordinary_choice,
                       :default => 'default') { | command_line |
      command_line.uses_option("-o", "--ordinary-choice CHOICE",
                               "CHOICE can be any string.")
    }

    builder.add_choice(:names) { | command_line |
      command_line.uses_arglist
    }
  end

  def execute
    pp @user_choices
  end
end


if $0 == __FILE__
  S4tUtils.with_pleasant_exceptions do
    MultipleSourcesExample.new.execute
  end
end
