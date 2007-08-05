require 'xmlsimple'
require 'yaml'
require 's4t-utils'
include S4tUtils

class Range # :nodoc:
  def in_words
    last_element = self.last
    last_element -= 1 if exclude_end?
    "#{self.first} to #{last_element}"
  end
end

class String # :nodoc:
  def to_inputable_sym
    gsub(/-/, '_').to_sym
  end
end


module UserChoices   # :nodoc


  class ExternallyFilledHash < Hash # :nodoc:
    def self.fill(*args); subclass_responsibility; end
    def source; subclass_responsibility; end

    def check_values(check_descriptions)
      check_descriptions.each { | key, check_description |
        next unless has_key?(key)
        check_one(key, check_description)
      }
    end

    def update_values(updates)
      updates.each { | key, update |
        next unless has_key?(key)
        if update == :integer
          self[key] = self[key].to_i
        elsif update == :boolean
          self[key] = eval(self[key].downcase)
        elsif update == [:string]
          return if self[key].is_a? Array
          self[key] = self[key].split(',')
        end
      }
    end

    private

    def initialize()
      super()
      @keys_to_external_names = {}
    end

    def error_prefix
      "Error in #{source}: "
    end

    def record_name_key_and_value(external_name, key, value)
      self[key] = value
      record_external_name(key, external_name)
    end

    def record_external_name(key, external_name)
      @keys_to_external_names[key] = external_name
    end

    def bad_look(key, like_what)
      error_prefix + "'#{external_name(key)}' requires #{like_what} value, and '#{self[key]}' doesn't look like one."
    end

    def check_one(key, check_description)
      if check_description == :integer
        user_claims(/^\d+$/ =~ (self[key])) { 
          bad_look(key, 'an integer')
        }
      elsif check_description == :boolean
        user_claims(['true', 'false'].include?(self[key].downcase)) {
          bad_look(key, 'a boolean')
        }
      elsif check_description == [:string]
        # Anything is OK
      elsif a_set_of_possible_values(check_description)
        user_claims(check_description.include?(self[key])) {
          error_prefix +
            "'#{self[key]}' is not a valid value for '#{external_name(key)}'."
        }
      end
    end



    def external_name(key)
      @keys_to_external_names[key]
    end

    def a_set_of_possible_values(thing)
      thing.respond_to?(:include?)
    end

  end

  class DefaultChoices < ExternallyFilledHash   # :nodoc:
    def self.fill(hash)
      instance = new
      instance.merge!(hash)
      instance.count_symbols_as_external_names(hash.keys)
      instance
    end

    def source
      "the default values"
    end

    def count_symbols_as_external_names(symbols)
      symbols.each { | symbol |
        # Use inspect so that symbol prints with leading colon
        @keys_to_external_names[symbol] = symbol.inspect
      }
    end
  end

  class ComposedChoices < ExternallyFilledHash  # :nodoc:

    def self.fill(*args, &checks_and_conversions)
      new(checks_and_conversions, *args)
    end

    def initialize(checks_and_conversions, *subordinates)
      super()
      @subordinates = subordinates
      checks_and_conversions.call(self) if checks_and_conversions
      @subordinates.reverse.each do | subordinate |
        self.merge!(subordinate)
      end
    end

    def source; 'this should never be seen'; end

    def check_values(check_descriptions)
      @subordinates.each do | subordinate | 
        subordinate.check_values(check_descriptions)
      end
    end

    def update_values(updates)
      @subordinates.each do | subordinate |
        subordinate.update_values(updates)
      end
    end
  end

  
  # Describe the environment as a source of choices. 
  class EnvironmentChoices < ExternallyFilledHash

    def self.fill(symbols_and_vars_of_interest)    # :nodoc:
      new(symbols_and_vars_of_interest)
    end

    # Environment variables beginning with _prefix_ (a string)
    # are considered to be user choices relevant to this script.
    # Everything after the prefix names a choice (that is, a symbol).
    # Dashes are converted to underscores. That is, +prefix-my-choice+
    # refers to the choice <tt>:my_choice</tt>.
    #
    # If you want an array of strings, separate the values by commas:
    # ENV_VAR=a,b,c
    # There's currently no way to escape a comma and no cleverness about
    # quotes. 
    #
    # _extras_ is a mapping from a choice to an environment variable
    # name. By saying <tt>:home => 'HOME'</tt>, you can capture the
    # value of <tt>$HOME</tt> even though it doesn't begin with a 
    # prefix.
    def self.with_prefix(prefix, extras = {})
      matches = ENV.collect do | env_var, ignored_value |
        if /^#{prefix}(.+)/ =~ env_var
          [$1.to_inputable_sym, env_var]
        end
      end
      fill(Hash[*matches.compact.flatten].merge(extras))
    end


    def initialize(symbols_and_vars_of_interest)     # :nodoc:
      super()
      @keys_to_external_names = symbols_and_vars_of_interest
      symbols_and_vars_of_interest.each { | key, env_var |
        self[key] = ENV[env_var] if ENV.has_key?(env_var)
      }
    end

    def source    # :nodoc:
      "the environment"
    end
  end
  
  class FileChoices < ExternallyFilledHash # :nodoc: 

    # Just a place to hang documentation, really.
    def self.from_file(filename); subclass_responsibility; end

    def self.fill(filename)    # :nodoc:
      prog1(new) do | retval |
        retval.record_path(filename)
        retval.make_choices(retval.read_into_hash)
      end
    end

    def source    # :nodoc:
      "configuration file #{@path}"
    end

    def make_choices(hash) # :nodoc: 
      hash.each do | external_name, value |
        sym = external_name.to_inputable_sym
        @keys_to_external_names[sym] = external_name
        self[sym] = value
      end
    end

    def read_into_hash    # :nodoc:
      return {} unless File.exist?(@path)
      begin
        format_specific_reading
      rescue Exception => ex
        if format_specific_exception?(ex)
          msg = "Badly formatted #{source}: " + format_specific_message(ex)
          ex = ex.class.new(msg)
        end
        raise ex
      end
    end

    def record_path(filename)
      @path = File.join(S4tUtils.find_home, filename)
    end

    protected 
    
    def format_specific_message(ex)
      ex.message
    end
    
    def format_specific_exception_handling(ex); subclass_responsibility; end
    def format_specific_reading; subclass_responsibility; end
  end

  # Use an XML file as a source of choices. The XML file is parsed
  # with <tt>XmlSimple('ForceArray' => false)</tt>. That means that
  # single elements like <home>Mars</home> are read as the value
  # <tt>"Mars"</tt>, whereas <home>Mars</home><home>Venus</home> is
  # read as <tt>["Mars", "Venus"]</tt>.
  class XmlConfigFileChoices < FileChoices

    # Treat _filename_ as the configuration file. _filename_ is expected
    # to be in the home directory. The home directory is found in the
    # same way Rubygems finds it. (First look in environment variables
    # <tt>$HOME</tt>, <tt>$USERPROFILE</tt>, <tt>$HOMEDRIVE:$HOMEPATH</tt>,
    # file expansion of <tt>"~"</tt> and finally the root.)
    def self.from_file(filename)
      fill(filename)
    end

    def format_specific_reading
      XmlSimple.xml_in(@path, 'ForceArray' => false)
    end
    
    def format_specific_exception?(ex)
      ex.is_a?(REXML::ParseException)
    end
    
    def format_specific_message(ex)
      ex.continued_exception
    end
      
  end
  
  
  
  # Use an YAML file as a source of choices. Note: because the YAML parser
  # can produce something out of many typo-filled YAML files, it's a 
  # good idea to check that your file looks like you'd expect before 
  # trusting in it. Do that with:
  #
  #    irb> require 'yaml'
  #    irb> YAML.load_file('config.yaml')
  #    
  class YamlConfigFileChoices < FileChoices
    # Treat _filename_ as the configuration file. _filename_ is expected
    # to be in the home directory. The home directory is found in the
    # same way Rubygems finds it. 
    def self.from_file(filename)
      fill(filename)
    end

    def format_specific_reading
      result = YAML.load_file(@path)
      ensure_hash_values_are_strings(result)
      result
    end

    def format_specific_exception?(ex)
      ex.is_a?(ArgumentError)
    end



    def ensure_hash_values_are_strings(h)
      h.each { |k, v| ensure_element_is_string(h, k) }
    end
    
    def ensure_array_values_are_strings(a)
      a.each_with_index { |elt, index| ensure_element_is_string(a, index) }
    end

    def ensure_element_is_string(collection, key)
      case collection[key]
        when Hash: ensure_hash_values_are_strings(collection[key])
        when Array: ensure_array_values_are_strings(collection[key])
        else collection[key] = collection[key].to_s
      end
    end
      
    
  end
end
