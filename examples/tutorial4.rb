#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-08-09.
#  Copyright (c) 2007. All rights reserved.


# See the tutorial for explanations.

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
    builder.add_source(CommandLineSource, :usage,
                       "Usage: ruby #{$0} [options] file1 [file2]")
    builder.add_source(EnvironmentSource, :with_prefix, "myprog_")
    builder.add_source(YamlConfigFileSource, :from_file, ".myprog-config.yml")
  end

  def add_choices(builder)
    builder.add_choice(:connections, :type=>:integer, :default=>0) { | command_line |
      command_line.uses_option("-c", "--connections COUNT",
                               "Number of connections to open.")
    }
    builder.add_choice(:ssh, :type=>:boolean, :default=>false) { | command_line |
      command_line.uses_switch("-s", "--ssh",
                               "Use ssh to open connection.")
    }
    builder.add_choice(:files, :length => 1..2) { | command_line | 
      command_line.uses_arglist
    }
  end

  def execute
    puts format("SSH %s be used.", @user_choices[:ssh] ? "should" : "should not")
    puts "There are #{@user_choices[:connections]} connections."
    pp @user_choices
  end
end


if $0 == __FILE__
  S4tUtils.with_pleasant_exceptions do
    TutorialExample.new.execute
  end
end
