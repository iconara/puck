
require 'bundler'

module Puck
  class Bundler
    def resolve_gem_dependencies(options = {})
      gemfile = options[:gemfile] || File.expand_path('Gemfile', options[:app_dir] || Dir.pwd)
      lockfile = options[:lockfile] || "#{gemfile}.lock"
      groups = options[:gem_groups] || [:default]

      gem_specs = ::Bundler::LockfileParser.new(File.read(lockfile)).specs.group_by(&:name)
      definition = ::Bundler::Definition.build(gemfile, lockfile, false)
      dependencies = definition.dependencies.select { |d| (d.groups & groups).any? }.map(&:name)
      bundler_specs = resolve_gem_specs(gem_specs, dependencies)

      specs = bundler_specs.map do |bundler_spec|
        case bundler_spec.source
        when ::Bundler::Source::Git
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
            load_path[index, load_path.length - index]
          end
          bin_path = File.join(gem_spec.full_name, gem_spec.bindir)
          {
            :name => gem_spec.name,
            :versioned_name => gem_spec.full_name,
            :base_path => base_path,
            :load_paths => load_paths,
            :bin_path => bin_path,
          }
        else
          raise GemNotFoundError, "Could not package #{bundler_spec.name} because no gemspec could be found at #{gemspec_path}."
        end
      end
      specs.uniq { |s| s[:versioned_name] }
    end

    private

    def resolve_gem_specs(gem_specs, gem_names)
      gem_names.flat_map do |name|
        gem_specs[name].flat_map do |spec|
          [spec, *resolve_gem_specs(gem_specs, spec.dependencies.map(&:name))]
        end
      end
    end
  end
end
