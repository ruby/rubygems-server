# frozen_string_literal: true

require 'rubygems'
require 'test/unit'

require 'fileutils'
require 'tmpdir'

class Gem::TestCase < Test::Unit::TestCase
  def assert_contains_specs(expected, specs)
    expected = expected.sort
    keys = expected.map {|item| item[0]}.uniq
    specs = specs.select {|item| keys.include?(item[0])}.sort
    assert_equal expected, specs
  end

  def setup
    @orig_env = ENV.to_hash
    @tmp = File.expand_path("tmp")

    FileUtils.mkdir_p @tmp

    ENV['GEM_VENDOR'] = nil
    ENV['GEMRC'] = nil
    ENV['XDG_CACHE_HOME'] = nil
    ENV['XDG_CONFIG_HOME'] = nil
    ENV['XDG_DATA_HOME'] = nil
    ENV['SOURCE_DATE_EPOCH'] = nil
    ENV['BUNDLER_VERSION'] = nil

    @current_dir = Dir.pwd

    @tempdir = Dir.mktmpdir("test_rubygems_", @tmp)

    ENV["TMPDIR"] = @tempdir

    @orig_SYSTEM_WIDE_CONFIG_FILE = Gem::ConfigFile::SYSTEM_WIDE_CONFIG_FILE
    Gem::ConfigFile.send :remove_const, :SYSTEM_WIDE_CONFIG_FILE
    Gem::ConfigFile.send :const_set, :SYSTEM_WIDE_CONFIG_FILE,
                         File.join(@tempdir, 'system-gemrc')

    @gemhome  = File.join @tempdir, 'gemhome'
    @userhome = File.join @tempdir, 'userhome'
    ENV["GEM_SPEC_CACHE"] = File.join @tempdir, 'spec_cache'

    Gem.ensure_gem_subdirectories @gemhome
    Gem.ensure_default_gem_subdirectories @gemhome

    @orig_LOAD_PATH = $LOAD_PATH.dup

    Dir.chdir @tempdir

    ENV['HOME'] = @userhome
    Gem.instance_variable_set :@config_file, nil
    Gem.instance_variable_set :@user_home, nil
    Gem.instance_variable_set :@config_home, nil
    Gem.instance_variable_set :@data_home, nil
    Gem.instance_variable_set :@gemdeps, nil
    Gem.instance_variable_set :@env_requirements_by_name, nil
    Gem.send :remove_instance_variable, :@ruby_version if
      Gem.instance_variables.include? :@ruby_version

    FileUtils.mkdir_p @userhome

    Gem.instance_variable_set(:@default_specifications_dir, nil)
    if Gem.java_platform?
      @orig_default_gem_home = RbConfig::CONFIG['default_gem_home']
      RbConfig::CONFIG['default_gem_home'] = @gemhome
    else
      Gem.instance_variable_set(:@default_dir, @gemhome)
    end

    @orig_bindir = RbConfig::CONFIG["bindir"]
    RbConfig::CONFIG["bindir"] = File.join @gemhome, "bin"

    Gem::Specification.unresolved_deps.clear
    Gem.use_paths(@gemhome)

    Gem.loaded_specs.clear
    Gem.instance_variable_set(:@activated_gem_paths, 0)
    Gem.clear_default_specs

    Gem.configuration.verbose = true
    Gem.configuration.update_sources = true
  end

  def teardown
    $LOAD_PATH.replace @orig_LOAD_PATH if @orig_LOAD_PATH

    Dir.chdir @current_dir

    FileUtils.rm_rf @tempdir
    FileUtils.rm_rf @tmp

    ENV.replace(@orig_env)

    Gem::ConfigFile.send :remove_const, :SYSTEM_WIDE_CONFIG_FILE
    Gem::ConfigFile.send :const_set, :SYSTEM_WIDE_CONFIG_FILE,
                         @orig_SYSTEM_WIDE_CONFIG_FILE

    RbConfig::CONFIG['bindir'] = @orig_bindir

    Gem.instance_variable_set :@default_specifications_dir, nil
    if Gem.java_platform?
      RbConfig::CONFIG['default_gem_home'] = @orig_default_gem_home
    else
      Gem.instance_variable_set :@default_dir, nil
    end

    Gem::Specification.unresolved_deps.clear
    Gem::Specification.reset
    Gem::refresh
  end

  def quick_gem(name, version = '2')
    spec = Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      yield(s) if block_given?
    end

    FileUtils.mkdir_p File.dirname(spec.spec_file)
    File.binwrite spec.spec_file, spec.to_ruby_for_cache

    spec.loaded_from = spec.spec_file

    Gem::Specification.reset

    spec
  end

  def util_spec(name, version = 2)
    Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      yield s if block_given?
    end
  end

  def self.process_based_port
    @@process_based_port ||= 8000 + $$ % 1000
  end

  def process_based_port
    self.class.process_based_port
  end

  def v(string)
    Gem::Version.create string
  end
end
