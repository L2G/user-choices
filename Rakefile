#!/usr/bin/env ruby
#
#  Created by Brian Marick on 2007-07-03.
#  Copyright (c) 2007. All rights reserved.

require 'hoe'
require 'lib/user-choices/version'

PROJECT='user-choices'
THIS_RELEASE=UserChoices::Version
ROOT = "svn+ssh://marick@rubyforge.org/var/svn/#{PROJECT}"
EXPORTS="#{ENV['HOME']}/tmp/exports"


Hoe.new(PROJECT, THIS_RELEASE) do |p|
  p.rubyforge_name = PROJECT
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

desc "Upload all the web pages"
task 'upload_pages' => ['export'] do
  Dir.chdir("#{EXPORTS}/#{PROJECT}") do
    exec = "scp -r tutorial/* marick@rubyforge.org:/var/www/gforge-projects/#{PROJECT}/"
    puts exec
    system(exec)
  end
end

desc "Tag release with current version."
task 'tag_release' do
  from = "#{ROOT}/trunk"
  to = "#{ROOT}/tags/rel-#{THIS_RELEASE}"
  message = "Release #{THIS_RELEASE}"
  exec = "svn copy -m '#{message}' #{from} #{to}"
  puts exec
  system(exec)
end

desc "Export to ~/tmp/exports/#{PROJECT}"
task 'export' do 
  Dir.chdir(EXPORTS) do
    rm_rf PROJECT
    exec = "svn export #{ROOT}/trunk #{PROJECT}"
    puts exec
    system exec
  end
end

desc "Complete release of everything"
task 'release_everything' => ['test', 'check_manifest', 'export', 'tag_release'] do
  Dir.chdir("#{EXPORTS}/#{PROJECT}") do
    `rake release`
    `rake upload_pages`
    `rake publish_docs`
  end
end