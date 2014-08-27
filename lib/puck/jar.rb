# encoding: utf-8

require 'fileutils'
require 'tmpdir'
require 'pathname'
require 'set'
require 'ant'
require 'bundler'
require 'puck/version'

begin
  require 'jruby-jars'
rescue LoadError
end

module Puck
  # Creates a standalone Jar file from your application.
  #
  # The Jar will contain your application code (which is assumed to be in the
  # "lib" directory), bin files (assumed to be in the "bin" directory), all the
  # gems in your default group (i.e. those that are not in a `group` block in
  # your Gemfile), including gems loaded from git, or from a path. It will also
  # contain a JRuby runtime so that to run it you only need a Java runtime.
  #
  # The Jar file will be configured so that you can run your application's bin
  # files by passing their name as the first argument after the Jar file (see example below).
  #
  # @example Creating a Jar from a Rake task
  #   task :jar do
  #     Puck::Jar.new.create!
  #   end
  #
  # @example Configuring the Jar file
  #   task :jar do
  #     jar = Puck::Jar.new(
  #       extra_files: Dir['config/*.yml'],
  #       jruby_complete: 'build/custom-jruby-complete.jar'
  #     )
  #     jar.create!
  #   end
  #
  # @example Running a bin file
  #     java -jar path/to/application.jar my-bin-file arg1 arg2
  #
  class Jar
    GemNotFoundError = Class.new(PuckError)
    # Create a new instance with the specified configuration.
    #
    # Puck tries to use sane defaults like assuming that the application name
    # is the same as the name of the directory containing the "lib" directory.
    #
    # @param [Hash] configuration
    # @option configuration [String] :extra_files a list of files to include in
    #   the Jar. The paths must be below the `:app_dir`.
    # @option configuration [String] :gem_groups ([:default]) a list of gem
    #   groups to include in the Jar. Remember to include the default group if
    #   you override this option.
    # @option configuration [String] :jruby_complete a path to the
    #   `jruby-complete.jar` that you want to use. If you don't specify this
    #   option you need to have `jruby-jars` in your `Gemfile` (it contains
    #   the equivalent of `jruby-complete.jar`. This option is mostly useful
    #   when you have a customized JRuby runtime that you want to use.
    # @option configuration [String] :app_dir (Dir.pwd)
    #   the application's base directory (i.e. the directory that contains the
    #   "lib" directory)
    # @option configuration [String] :app_name (File.basename(configuration[:app_dir]))
    #   the name of the application, primarily used to name the Jar
    # @option configuration [String] :build_dir ("build") the directory where
    #   the Jar file will be created
    #
    def initialize(configuration={})
      @configuration = configuration.dup
      @configuration[:app_dir] ||= Dir.pwd
      @configuration[:app_name] ||= File.basename(@configuration[:app_dir])
      @configuration[:build_dir] ||= File.join(@configuration[:app_dir], 'build')
      @configuration[:jar_name] ||= @configuration[:app_name] + '.jar'
      @configuration[:gem_groups] ||= [:default]
    end

    # Create the Jar file using the instance's configuration.
    #
    def create!
      FileUtils.mkdir_p(@configuration[:build_dir])

      Dir.mktmpdir do |tmp_dir|
        output_path = File.join(@configuration[:build_dir], @configuration[:jar_name])
        project_dir = Pathname.new(@configuration[:app_dir])
        extra_files = @configuration[:extra_files] || []
        jruby_complete_path = @configuration[:jruby_complete]

        if !(defined? JRubyJars) && !(jruby_complete_path && File.exists?(jruby_complete_path))
          raise PuckError, 'Cannot build Jar: jruby-jars must be installed, or :jruby_complete must be specified'
        end

        gem_dependencies = resolve_gem_dependencies
        create_jar_bootstrap!(tmp_dir, gem_dependencies)

        ant = Ant.new(output_level: 1)
        ant.jar(destfile: output_path) do
          manifest do
            attribute name: 'Main-Class', value: 'org.jruby.JarBootstrapMain'
            attribute name: 'Created-By', value: "Puck v#{Puck::VERSION}"
          end

          zipfileset dir: tmp_dir, includes: 'jar-bootstrap.rb'

          if jruby_complete_path
            zipfileset src: jruby_complete_path
          else
            zipfileset src: JRubyJars.core_jar_path
            zipfileset src: JRubyJars.stdlib_jar_path
          end

          %w[bin lib].each do |sub_dir|
            zipfileset dir: project_dir + sub_dir, prefix: File.join(JAR_APP_HOME, sub_dir)
          end

          extra_files.each do |ef|
            path = Pathname.new(ef).expand_path.cleanpath
            prefix = File.join(JAR_APP_HOME, path.relative_path_from(project_dir).dirname.to_s)
            zipfileset dir: path.dirname, prefix: prefix, includes: path.basename
          end

          gem_dependencies.each do |spec|
            zipfileset dir: spec[:base_path], prefix: spec[:jar_path]
          end
        end
      end
    end

    private

    JAR_APP_HOME = 'META-INF/app.home'.freeze
    JAR_GEM_HOME = 'META-INF/gem.home'.freeze
    JAR_JRUBY_HOME = 'META-INF/jruby.home'.freeze

    def resolve_gem_dependencies
      gem_specs = Bundler::LockfileParser.new(File.read('Gemfile.lock')).specs.group_by(&:name)
      definition = Bundler::Definition.build('Gemfile', 'Gemfile.lock', false)
      dependencies = definition.dependencies.select { |d| (d.groups & @configuration[:gem_groups]).any? }.map(&:name)
      specs = resolve_gem_specs(gem_specs, dependencies)
      specs = specs.map do |bundler_spec|
        case bundler_spec.source
        when Bundler::Source::Git
          gemspec_path = File.join(ENV['GEM_HOME'], 'bundler', 'gems', "#{bundler_spec.source.extension_dir_name}", "#{bundler_spec.name}.gemspec")
          base_path = File.dirname(gemspec_path)
        else
          gemspec_path = File.join(ENV['GEM_HOME'], 'specifications', "#{bundler_spec.full_name}.gemspec")
          base_path = File.join(ENV['GEM_HOME'], 'gems', bundler_spec.full_name)
        end
        if File.exists?(gemspec_path)
          gem_spec = Gem::Specification.load(gemspec_path)
          load_paths = gem_spec.load_paths.map do |load_path|
            index = load_path.index(gem_spec.full_name)
            File.join(JAR_GEM_HOME, load_path[index, load_path.length - index])
          end
          bin_path = File.join(JAR_GEM_HOME, gem_spec.full_name, gem_spec.bindir)
          {
            :name => gem_spec.name,
            :versioned_name => gem_spec.full_name,
            :base_path => base_path,
            :jar_path => File.join(JAR_GEM_HOME, gem_spec.full_name),
            :load_paths => load_paths,
            :bin_path => bin_path,
          }
        else
          raise GemNotFoundError, "Could not package #{bundler_spec.name} because no gemspec could be found at #{gemspec_path}."
        end
      end
      specs.uniq { |s| s[:versioned_name] }
    end

    def resolve_gem_specs(gem_specs, gem_names)
      gem_names.flat_map do |name|
        gem_specs[name].flat_map do |spec|
          [spec, *resolve_gem_specs(gem_specs, spec.dependencies.map(&:name))]
        end
      end
    end

    def create_jar_bootstrap!(tmp_dir, gem_dependencies)
      File.open(File.join(tmp_dir, 'jar-bootstrap.rb'), 'w') do |io|
        io.puts(%(PUCK_BIN_PATH = ['/#{JAR_APP_HOME}/bin', '/#{JAR_JRUBY_HOME}/bin']))
        gem_dependencies.each do |spec|
          io.puts("PUCK_BIN_PATH << '/#{spec[:bin_path]}'")
        end
        io.puts
        gem_dependencies.each do |spec|
          spec[:load_paths].each do |load_path|
            io.puts(%($LOAD_PATH << 'classpath:#{load_path}'))
          end
        end
        io.puts
        io.puts(File.read(File.expand_path('../bootstrap.rb', __FILE__)))
      end
    end
  end
end
