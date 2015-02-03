# encoding: utf-8

require 'fileutils'
require 'tmpdir'
require 'pathname'
require 'set'
require 'ant'
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
      @dependency_resolver = @configuration[:dependency_resolver] || DependencyResolver.new
    end

    # Create the Jar file using the instance's configuration.
    #
    def create!
      FileUtils.mkdir_p(@configuration[:build_dir])

      ["bin", "lib"].each do |directory|
        if Dir.glob("#{directory}/{*,.*}").empty?
          raise PuckError, "Cannot build Jar: #{directory} directory not present / empty"
        end
      end
      Dir.mktmpdir do |tmp_dir|
        output_path = File.join(@configuration[:build_dir], @configuration[:jar_name])
        project_dir = Pathname.new(@configuration[:app_dir]).expand_path.cleanpath
        extra_files = @configuration[:extra_files] || []
        jruby_complete_path = @configuration[:jruby_complete]

        if !(defined? JRubyJars) && !(jruby_complete_path && File.exists?(jruby_complete_path))
          raise PuckError, 'Cannot build Jar: jruby-jars must be installed, or :jruby_complete must be specified'
        end

        gem_dependencies = @dependency_resolver.resolve_gem_dependencies(@configuration)
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
            base_path = Pathname.new(spec[:base_path]).expand_path.cleanpath
            unless project_dir == base_path
              zipfileset dir: spec[:base_path], prefix: File.join(JAR_GEM_HOME, spec[:versioned_name])
            end
          end
        end
      end
    end

    private

    JAR_APP_HOME = 'META-INF/app.home'.freeze
    JAR_GEM_HOME = 'META-INF/gem.home'.freeze
    JAR_JRUBY_HOME = 'META-INF/jruby.home'.freeze

    def create_jar_bootstrap!(tmp_dir, gem_dependencies)
      File.open(File.join(tmp_dir, 'jar-bootstrap.rb'), 'w') do |io|
        io.puts(%(PUCK_BIN_PATH = ['/#{JAR_APP_HOME}/bin', '/#{JAR_JRUBY_HOME}/bin']))
        gem_dependencies.each do |spec|
          io.puts("PUCK_BIN_PATH << '/#{JAR_GEM_HOME}/#{spec[:versioned_name]}/#{spec[:bin_path]}'")
        end
        io.puts
        gem_dependencies.each do |spec|
          spec[:load_paths].each do |load_path|
            io.puts(%($LOAD_PATH << 'classpath:#{JAR_GEM_HOME}/#{spec[:versioned_name]}/#{load_path}'))
          end
        end
        io.puts
        io.puts(File.read(File.expand_path('../bootstrap.rb', __FILE__)))
      end
    end
  end
end
