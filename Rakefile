#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-07-03.
#  Copyright (c) 2007. All rights reserved.

require 'hoe'
require 'lib/user-choices/version'

Hoe.new("user-choices", UserChoices::Version) do |p|
  p.rubyforge_name = "user-choices"
  p.changes = "See History.txt"
  p.author = "Brian Marick"
  p.description = "Unified interface to command-line, environment, and configuration files."
  p.summary = p.description
  p.email = "marick@exampler.com"
  p.extra_deps = [['xml-simple', '>= 1.0.11'], 
                  ['s4t-utils', '>= 1.0.3'],
                  ['builder', '>= 2.1.2']]        # for testing
  p.test_globs = "test/**/*tests.rb"
  p.rdoc_pattern = %r{README.txt|History.txt|lib/user-choices.rb|lib/user-choices/.+\.rb}
  p.url = "http://user-choices.rubyforge.org"
  p.remote_rdoc_dir = 'rdoc'
end

require 's4t-utils/rake-task-helpers'
desc "Run fast tests."
task 'fast' do
  S4tUtils.run_particular_tests('test', 'fast')
end

desc "Run slow tests."
task 'slow' do
  S4tUtils.run_particular_tests('test', 'slow')
end
