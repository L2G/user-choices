load "set-standalone-test-paths.rb" unless $started_from_rakefile
require 'test/unit'
require 's4t-utils'
require 'user-choices'
include S4tUtils



class Examples < Test::Unit::TestCase
  def evalue(command)
    result = `#{command}`
    eval(result)
  end

  RUBY = "ruby #{PACKAGE_ROOT}/examples/"

  require "#{PACKAGE_ROOT}/examples/command-line"
  # require "#{PACKAGE_ROOT}/examples/default-values" # not needed
  require "#{PACKAGE_ROOT}/examples/multiple-sources"
  # require "#{PACKAGE_ROOT}/examples/postprocess" # not needed
  require "#{PACKAGE_ROOT}/examples/switches"
  require "#{PACKAGE_ROOT}/examples/two-args"
  require "#{PACKAGE_ROOT}/examples/types"


  def test_succeeding_examples
    val = evalue("#{RUBY}command-line.rb --choice cho sophie paul dawn me")
    assert_equal({:names => ["sophie", "paul", "dawn", "me"],
                   :choice=>"cho"},
                 val)

    val = evalue("#{RUBY}command-line.rb -c choice")
    assert_equal({:names => [], :choice => "choice"}, val)

    val = evalue("#{RUBY}command-line.rb -cchoice")
    assert_equal({:names => [], :choice => "choice"}, val)

    val = evalue("#{RUBY}command-line.rb --choi choice")
    assert_equal({:names => [], :choice => "choice"}, val)

    val = evalue("#{RUBY}command-line.rb --choi choice -- -name1- -name2-")
    assert_equal({:names => ['-name1-', '-name2-'], :choice => 'choice'}, val)


    val = evalue("#{RUBY}default-values.rb --choice specific")
    assert_equal({:choice => 'specific'}, val)

    val = evalue("#{RUBY}default-values.rb")
    assert_equal({:choice => 'default'}, val)

    val = evalue("#{RUBY}default-values.rb only-arg")
    assert_equal({:choice => 'default', :name => 'only-arg'}, val)


    val = evalue("#{RUBY}types.rb --must-be-integer 3 argument")
    assert_equal({:arg => 'argument', :must_be_integer => 3}, val)


    val = evalue("#{RUBY}switches.rb 1 2")
    assert_equal({:switch=> false, :args => ['1', '2']}, val)

    val = evalue("#{RUBY}switches.rb --switch 1 2")
    assert_equal({:switch=> true, :args => ['1', '2']}, val)

    val = evalue("#{RUBY}switches.rb -s 2 1 ")
    assert_equal({:switch=> true, :args => ['2', '1']}, val)

    val = evalue("#{RUBY}switches.rb --no-switch 1 2")
    assert_equal({:switch=> false, :args => ['1', '2']}, val)

    val = evalue("#{RUBY}switches.rb 1  2  3 4")
    assert_equal({:switch=> false, :args => ['1', '2', '3', '4']}, val)


    val = evalue("#{RUBY}two-args.rb 1 2 ")
    assert_equal({:args => ['1', '2']}, val)


    val = evalue("#{RUBY}postprocess.rb 1 2")
    assert_equal({:infile => '1', :outfile => '2', :args => ['1', '2']},
                 val)
  end

  def test_multiple_sources_xml
    xml = "<config><ordinary_choice>greetings</ordinary_choice></config>"

    with_local_config_file("ms-config.xml", xml) {
      val = evalue("#{RUBY}multiple-sources.rb")
      assert_equal({:names => [], :ordinary_choice => 'greetings'}, val)
    }

    with_local_config_file("ms-config.xml", xml) {
      with_environment_vars("ms_ordinary_choice" => 'hi') { 
        val = evalue("#{RUBY}multiple-sources.rb ")
        assert_equal({:names => [], :ordinary_choice => 'hi'}, val)
      }
    }
    

    with_local_config_file("ms-config.xml", xml) {
      with_environment_vars("ms_ordinary_choice" => 'hi') { 
        val = evalue("#{RUBY}multiple-sources.rb --ordinary-choice hello")
        assert_equal({:names => [], :ordinary_choice => 'hello'}, val)
      }
    }

  end


  def test_multiple_sources_yaml
    yml = "ordinary_choice: greetings"

    with_local_config_file("ms-config.yml", yml) {
      val = evalue("#{RUBY}multiple-sources.rb")
      assert_equal({:names => [], :ordinary_choice => 'greetings'}, val)
    } 

    with_local_config_file("ms-config.yml", yml) {
      with_environment_vars("ms_ordinary_choice" => 'hi') { 
        val = evalue("#{RUBY}multiple-sources.rb ")
        assert_equal({:names => [], :ordinary_choice => 'hi'}, val)
      }
    }
    

    with_local_config_file("ms-config.yml", yml) {
      with_environment_vars("ms_ordinary_choice" => 'hi') { 
        val = evalue("#{RUBY}multiple-sources.rb --ordinary-choice hello")
        assert_equal({:names => [], :ordinary_choice => 'hello'}, val)
      }
    }

  end


  def error(klass, args)
    capturing_stderr {
      with_pleasant_exceptions {
        with_command_args(args) {
          klass.new.execute
        }
      }
    }
  end

  def test_error_checking
    assert_match(/missing argument: --choice/,
                 error(CommandLineExample,  "--choice"))


    assert_match(/invalid option: --other/,
                 error(CommandLineExample,  "--other 3 -- choice"))

    
    assert_match(/--a-or-b's value must be one of 'a' or 'b'.*'not-a' doesn't look right/,
                 error(TypesExample,  "--a-or-b not-a  argument"))

    
    assert_match(/--must-be-integer's value must be an integer/,
                 error(TypesExample,  "--must-be-integer 1d argument"))


    assert_match(/0 arguments given, 1 expected/, 
                 error(TypesExample,  ""))

    assert_match(/2 arguments given, 1 expected/, 
                 error(TypesExample,  "argument extra"))

    assert_match(/1 argument given, 2 to 4 expected/, 
                 error(SwitchExample,  "1"))

    assert_match(/5 arguments given, 2 to 4 expected/, 
                 error(SwitchExample,  "1 2 3 4 5"))

    assert_match(/1 argument given, 2 expected/, 
                 error(TwoArgExample,  "1"))

    assert_match(/3 arguments given, 2 expected/, 
                 error(TwoArgExample,  "1 2 3"))

  end

  def test_bad_xml
    xml = "<config><names"
    with_local_config_file("ms-config.xml", xml) {
      assert_match(/Badly formatted configuration file/,
                     error(MultipleSourcesExample,  "1 2")  )
    }
  end


  def test_help
    result = error(CommandLineExample, "--help")
    assert_match(/Usage.*Options:.*--choice.*CHOICE can be.*Show this/m,
                 result)

    result = error(SwitchExample, "--help")
    assert_match(/Usage.*Options:.*--\[no-\]switch.*Show this message/m,
                 result)
  end
  
  
  def test_tutorial_usage_section
    assert_match(/There are 0 connections./, `#{RUBY}tutorial1.rb `)
    
    with_local_config_file(".myprog-config.yml", "connections: 19") do
      assert_match(/There are 19 connections./, `#{RUBY}tutorial1.rb `)
      
      with_environment_vars("myprog_connections" => '3') do
        assert_match(/There are 3 connections./, `#{RUBY}tutorial1.rb `)

        assert_match(/There are 999 connections./, 
                     `#{RUBY}tutorial1.rb --connection 999`)
      end

      with_environment_vars("myprog_connections" => 'hi') do
        assert_match(/Error in the environment: myprog_connections's value must be an integer, and 'hi' doesn't look right/, 
                     `#{RUBY}tutorial1.rb 2>&1`)
                     
      end
      
      output = `#{RUBY}tutorial1.rb --connections hi 2>&1`
      assert_match(/Error in the command line: --connections's value must be an integer, and 'hi' doesn't look right/,
                   output)
      assert_match(/Usage: ruby.*tutorial1.rb/, output)
    end
  end
  
  def test_tutorial_command_line_behavior_section
    assert_match(/SSH should be used/, `#{RUBY}tutorial2.rb --ssh`)
    assert_match(/SSH should be used/, `#{RUBY}tutorial2.rb -s`)
    assert_match(/-s,\s+--\[no-\]ssh/, `#{RUBY}tutorial2.rb --help 2>&1`)
    
    output = `#{RUBY}tutorial3.rb arg1 arg2`
    assert_match(/:files\s*=>\s*\["arg1", "arg2"\]/, output)
    
    yaml = "
      connections: 19
      files:
        - one
        - two
      "

    with_local_config_file(".myprog-config.yml", yaml) do
      output = `#{RUBY}tutorial3.rb cmd`
      assert_match(/:files\s*=>\s*\["cmd"\]/, output)
    
      output = `#{RUBY}tutorial3.rb`
      assert_match(/:files\s*=>\s*\["one", "two"\]/, output)
      
      output = `#{RUBY}tutorial4.rb 1 2 3 2>&1`
      assert_match(/Error in the command line: 3 arguments given, 1 or 2 expected/, output)
      
      output = `#{RUBY}tutorial4.rb`
      assert_match(/:files\s*=>\s*\["one", "two"\]/, output)
    end
    
    assert_match(/:infile=>"1"/, `#{RUBY}tutorial5.rb 1`)
    assert_match(/Error in the command line: 0 arguments given, 1 expected./,
                 `#{RUBY}tutorial5.rb 2>&1`)

    assert_match(/\{\}/, `#{RUBY}tutorial6.rb`)
  end
  
  def test_tutorial_touchup_section
    output = `#{RUBY}tutorial7.rb one two`
    assert_match(/:infile=>"one"/, output)
    assert_match(/:outfile=>"two"/, output)
    assert_match(/:files=>\["one", "two"\]/, output)
  end

end

