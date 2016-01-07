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
  #     Puck::Jar.new.create
  #   end
  #
  # @example Configuring the Jar file
  #   task :jar do
  #     jar = Puck::Jar.new(
  #       extra_files: Dir['config/*.yml'],
  #       jruby_complete: 'build/custom-jruby-complete.jar',
  #       merge_archives: Dir['external.jar']
  #     )
  #     jar.create
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
    # @option configuration [Array<String>, Hash<String,String>] :extra_files a
    #   list of files to include in the Jar. The option can be either an Array,
    #   in which case paths must be below the `:app_dir`, or a Hash, in which
    #   case the file specified by the key is included at the path specified by
    #   the corresponding value.
    # @option configuration [Array<String>, Hash<String,String>] :merge_archives
    #   a list of Jars to be merged into the Jar. The option can be either an Array,
    #   in which case the source Jar or zip file will be merged at the root,
    #   or a Hash, in which case the Jar specified by the key is merged at the path
    #   specified by its value. Signature files ('META-INF/*.SF', 'META-INF/*.RSA',
    #   'META-INF/*.DSA' and 'META-INF/SIG-*') are discarded in the merge,
    #   since they describe the source Jar and will not match the Jar produced by Puck.
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
    # @return The path to the Jar file
    #
    def create
      FileUtils.mkdir_p(@configuration[:build_dir])

      Dir.mktmpdir do |tmp_dir|
        output_path = File.join(@configuration[:build_dir], @configuration[:jar_name])
        temporary_output_path = File.join(Dir.mktmpdir, @configuration[:jar_name])
        project_dir = Pathname.new(@configuration[:app_dir]).expand_path.cleanpath
        extra_files = @configuration[:extra_files] || []

        if !(defined? JRubyJars) && !(jruby_complete_path && File.exists?(jruby_complete_path))
          raise PuckError, 'Cannot build Jar: jruby-jars must be installed, or :jruby_complete must be specified'
        end

        merge_archives = (@configuration[:merge_archives] || []).to_a
        if (jruby_complete = @configuration[:jruby_complete])
          merge_archives << jruby_complete
        else
          merge_archives.push(JRubyJars.core_jar_path, JRubyJars.stdlib_jar_path)
        end

        gem_dependencies = @dependency_resolver.resolve_gem_dependencies(@configuration)
        create_jar_bootstrap!(tmp_dir, gem_dependencies)

        ant = Ant.new(output_level: 1)
        begin
          ant.jar(destfile: temporary_output_path) do
            manifest do
              attribute name: 'Main-Class', value: 'org.jruby.JarBootstrapMain'
              attribute name: 'Created-By', value: "Puck v#{Puck::VERSION}"
            end

            zipfileset dir: tmp_dir, includes: 'jar-bootstrap.rb'

            %w[bin lib].each do |sub_dir|
              path = project_dir + sub_dir
              if File.exists?(path)
                zipfileset dir: path, prefix: File.join(JAR_APP_HOME, sub_dir)
              end
            end

            extra_files.each do |file, target_path|
              path = Pathname.new(file).expand_path.cleanpath
              if target_path
                zipfileset file: path, fullpath: target_path
              else
                prefix = File.join(JAR_APP_HOME, path.relative_path_from(project_dir).dirname.to_s)
                zipfileset dir: path.dirname, prefix: prefix, includes: path.basename
              end
            end

            gem_dependencies.each do |spec|
              base_path = Pathname.new(spec[:base_path]).expand_path.cleanpath
              unless project_dir == base_path
                zipfileset dir: spec[:base_path], prefix: File.join(JAR_GEM_HOME, spec[:versioned_name])
              end
            end

            merge_archives.each do |archive, target_path|
              if target_path
                zipfileset src: archive, prefix: target_path, excludes: SIGNATURE_FILES
              else
                zipfileset src: archive, excludes: SIGNATURE_FILES
              end
            end
          end

          FileUtils.mv(temporary_output_path, output_path)
        rescue Java::OrgApacheToolsAnt::BuildException => e
          raise PuckError, sprintf('Error when building JAR: %s (%s)', e.message, e.class), e.backtrace
        ensure
          FileUtils.rm_rf(File.dirname(temporary_output_path))
        end
        output_path
      end
    end

    # @deprecated Use #create
    def create!
      create
    end

    private

    JAR_APP_HOME = 'META-INF/app.home'.freeze
    JAR_GEM_HOME = 'META-INF/gem.home'.freeze
    JAR_JRUBY_HOME = 'META-INF/jruby.home'.freeze
    SIGNATURE_FILES = ['META-INF/*.SF', 'META-INF/*.RSA', 'META-INF/*.DSA', 'META-INF/SIG-*'].join(',').freeze

    def create_jar_bootstrap!(tmp_dir, gem_dependencies)
      File.open(File.join(tmp_dir, 'jar-bootstrap.rb'), 'w') do |io|
        io.puts(%(PUCK_ROOT = JRuby.runtime.jruby_class_loader.get_resource('jar-bootstrap.rb').to_s.chomp('jar-bootstrap.rb')))
        io.puts(%(PUCK_BIN_PATH = ['#{JAR_APP_HOME}/bin', '#{JAR_JRUBY_HOME}/bin']))
        gem_dependencies.each do |spec|
          io.puts("PUCK_BIN_PATH << '#{JAR_GEM_HOME}/#{spec[:versioned_name]}/#{spec[:bin_path]}'")
        end
        io.puts
        gem_dependencies.each do |spec|
          spec[:load_paths].each do |load_path|
            io.puts(%($LOAD_PATH << File.join(PUCK_ROOT, '#{JAR_GEM_HOME}/#{spec[:versioned_name]}/#{load_path}')))
          end
        end
        io.puts
        io.puts(File.read(File.expand_path('../bootstrap.rb', __FILE__)))
      end
    end
  end
end
