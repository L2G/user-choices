#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-07-03.
#  Copyright (c) 2007. All rights reserved.

require 'hoe'
$:.unshift(File.join(Dir.pwd, "lib"))
require 'user-choices/version'

PROJECT='user-choices'
THIS_RELEASE=UserChoices::Version


Hoe.spec(PROJECT) do |spec|
  spec.rubyforge_name = PROJECT
  spec.version = THIS_RELEASE
  spec.changes = "See History.txt"
  spec.author = "Brian Marick"
  spec.description = "Unified interface to command-line, environment, and configuration files."
  spec.summary = spec.description
  spec.email = "marick@exampler.com"
  spec.extra_deps = [['xml-simple', '>= 1.0.11'],
                  ['s4t-utils', '>= 1.0.3'],
                  ['builder', '>= 2.1.2']]        # for testing
  spec.test_globs = "test/**/*tests.rb"
  spec.extra_rdoc_files = ['README.txt', 'History.txt']
  spec.url = "http://user-choices.rubyforge.org"
  spec.remote_rdoc_dir = 'rdoc'
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

require 's4t-utils/hoelike'
HoeLike.new(:project => PROJECT, :this_release => THIS_RELEASE,
            :login => "marick@rubyforge.org",
            :web_site_root => 'examples/tutorial', 
            :export_root => "#{S4tUtils.find_home}/tmp/exports")
