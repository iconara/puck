# encoding: utf-8

require 'fileutils'
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
      output_path = File.join(@configuration[:build_dir], @configuration[:jar_name])
      project_lib_dir = File.join(@configuration[:base_dir], 'lib')
      gem_dependencies = resolve_gem_dependencies

      FileUtils.mkdir_p(@configuration[:build_dir])

      ant = Ant.new(output_level: 1)
      ant.jar(destfile: output_path) do
        manifest do
          attribute name: 'Main-Class', value: 'org.jruby.JarBootstrapMain'
          attribute name: 'Created-By', value: "Jarbler v#{Jarbler::VERSION}"
        end
        zipfileset dir: project_lib_dir, prefix: 'META-INF/app.home/lib'
        zipfileset src: JRubyJars.core_jar_path
        zipfileset src: JRubyJars.stdlib_jar_path

        gem_dependencies.each do |name_with_version, path|
          zipfileset dir: path, prefix: "META-INF/gem.home/#{name_with_version}"
        end
      end
    end

    def resolve_gem_dependencies
      gem_specs = Bundler::LockfileParser.new(File.read('Gemfile.lock')).specs.group_by(&:name)
      definition = Bundler::Definition.build('Gemfile', 'Gemfile.lock', false)
      dependencies = definition.dependencies.select { |d| d.groups.include?(:default) }.map(&:name)
      resolve_gem_specs(gem_specs, dependencies).each_with_object({}) do |spec, acc|
        case spec.source
        when Bundler::Source::Git
          revision = spec.source.options['revision']
          acc[spec.full_name] = File.join(ENV['GEM_HOME'], 'bundler', 'gems', "#{spec.name}-#{revision[0, 12]}")
        else
          acc[spec.full_name] = File.join(ENV['GEM_HOME'], 'gems', spec.full_name)
        end
      end
    end

    def resolve_gem_specs(gem_specs, gem_names)
      gem_names.flat_map do |name|
        gem_specs[name].flat_map do |spec|
          [spec, *resolve_gem_specs(gem_specs, spec.dependencies.map(&:name))]
        end
      end
    end
  end
end
