# encoding: utf-8

require 'fileutils'
require 'tmpdir'
require 'set'
require 'ant'
require 'bundler'
require 'jruby-jars'
require 'jarbler/version'


module Jarbler
  class Jar
    def initialize(configuration={})
      @configuration = configuration.dup
      @configuration[:base_dir] ||= Dir.pwd
      @configuration[:project_name] ||= File.basename(@configuration[:base_dir])
      @configuration[:build_dir] ||= File.join(@configuration[:base_dir], 'build')
      @configuration[:jar_name] ||= @configuration[:project_name] + '.jar'
    end

    def create!
      Dir.mktmpdir do |tmp_dir|
        output_path = File.join(@configuration[:build_dir], @configuration[:jar_name])
        project_lib_dir = File.join(@configuration[:base_dir], 'lib')
        gem_dependencies = resolve_gem_dependencies
        create_jar_bootstrap!(tmp_dir, gem_dependencies)

        FileUtils.mkdir_p(@configuration[:build_dir])

        ant = Ant.new(output_level: 1)
        ant.jar(destfile: output_path) do
          manifest do
            attribute name: 'Main-Class', value: 'org.jruby.JarBootstrapMain'
            attribute name: 'Created-By', value: "Jarbler v#{Jarbler::VERSION}"
          end

          zipfileset dir: tmp_dir, includes: 'jar-bootstrap.rb'
          zipfileset dir: project_lib_dir, prefix: 'META-INF/app.home/lib'
          zipfileset src: JRubyJars.core_jar_path
          zipfileset src: JRubyJars.stdlib_jar_path

          gem_dependencies.each do |spec|
            zipfileset dir: spec[:base_path], prefix: spec[:jar_path]
          end
        end
      end
    end

    def resolve_gem_dependencies
      gem_specs = Bundler::LockfileParser.new(File.read('Gemfile.lock')).specs.group_by(&:name)
      definition = Bundler::Definition.build('Gemfile', 'Gemfile.lock', false)
      dependencies = definition.dependencies.select { |d| d.groups.include?(:default) }.map(&:name)
      specs = resolve_gem_specs(gem_specs, dependencies)
      specs = specs.map do |bundler_spec|
        case bundler_spec.source
        when Bundler::Source::Git
          revision = bundler_spec.source.options['revision']
          gemspec_path = File.join(ENV['GEM_HOME'], 'bundler', 'gems', "#{bundler_spec.name}-#{revision[0, 12]}", "#{bundler_spec.name}.gemspec")
          base_path = File.dirname(gemspec_path)
        else
          gemspec_path = File.join(ENV['GEM_HOME'], 'specifications', "#{bundler_spec.full_name}.gemspec")
          base_path = File.join(ENV['GEM_HOME'], 'gems', bundler_spec.full_name)
        end
        gem_spec = Gem::Specification.load(gemspec_path)
        load_paths = gem_spec.load_paths.map do |load_path|
          index = load_path.index(gem_spec.full_name)
          "META-INF/gem.home/" + load_path[index, load_path.length - index]
        end
        {
          :name => gem_spec.name,
          :versioned_name => gem_spec.full_name,
          :base_path => base_path,
          :jar_path => "META-INF/gem.home/#{gem_spec.full_name}",
          :load_paths => load_paths
        }
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
        gem_dependencies.each do |spec|
          spec[:load_paths].each do |load_path|
            io.puts(%($LOAD_PATH << 'classpath:#{load_path}'))
          end
        end
      end
    end
  end
end
