
require 'bundler'

module Puck
  class DependencyResolver
    def resolve_gem_dependencies(options = {})
      gemfile = options[:gemfile] || File.expand_path('Gemfile', options[:app_dir] || Dir.pwd)
      lockfile = options[:lockfile] || "#{gemfile}.lock"
      groups = options[:gem_groups] || [:default]

      definition = Bundler::Definition.build(gemfile, lockfile, false)
      gem_specs = definition.specs_for(groups).to_a
      gem_specs.delete_if { |gem_spec| gem_spec.name == 'bundler' }
      gem_specs.map do |gem_spec|
        base_path = gem_spec.full_gem_path.chomp('/')
        load_paths = gem_spec.load_paths.map do |load_path|
          unless load_path.start_with?(base_path)
            raise PuckError, 'Unsupported load path "%s" in gem "%s"' % [load_path, bundler_spec.name]
          end
          File.join(gem_spec.full_name, load_path[base_path.size + 1, load_path.length - base_path.size - 1])
        end
        bin_path = File.join(gem_spec.full_name, gem_spec.bindir)
        {
          :name => gem_spec.name,
          :versioned_name => gem_spec.full_name,
          :base_path => base_path,
          :load_paths => load_paths,
          :bin_path => bin_path,
        }
      end
    end
  end
end
