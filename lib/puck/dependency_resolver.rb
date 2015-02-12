require 'stringio'
require 'bundler'

module Puck
  # @private
  class DependencyResolver
    def resolve_gem_dependencies(options = {})
      gem_home = options[:gem_home] || ENV['GEM_HOME']
      gemfile = options[:gemfile] || File.expand_path('Gemfile', options[:app_dir] || Dir.pwd)
      lockfile = options[:lockfile] || "#{gemfile}.lock"
      groups = options[:gem_groups] || [:default]

      bundler_specs = contained_bundler(gem_home, gemfile, lockfile, groups)
      bundler_specs.delete_if { |spec| spec[:name] == 'bundler' }
      bundler_specs.map do |spec|
        base_path = spec[:full_gem_path].chomp('/')
        load_paths = spec[:load_paths].map do |load_path|
          unless load_path.start_with?(base_path)
            raise PuckError, 'Unsupported load path "%s" in gem "%s"' % [load_path, bundler_spec.name]
          end
          load_path[base_path.size + 1, load_path.length - base_path.size - 1]
        end
        {
          :name => spec[:name],
          :versioned_name => spec[:full_name],
          :base_path => base_path,
          :load_paths => load_paths,
          :bin_path => spec[:bindir],
        }
      end
    end

    private

    def contained_bundler(gem_home, gemfile, lockfile, groups)
      Bundler.with_clean_env do
        scripting_container = Java::OrgJrubyEmbed::ScriptingContainer.new(Java::OrgJrubyEmbed::LocalContextScope::SINGLETHREAD)
        scripting_container.compat_version = Java::OrgJruby::CompatVersion::RUBY1_9
        scripting_container.current_directory = Dir.pwd
        scripting_container.environment = Hash[ENV.merge('GEM_HOME' => gem_home).map { |k,v| [k.to_java, v.to_java] }]
        scripting_container.put('arguments', Marshal.dump([gemfile, lockfile, groups]).to_java_bytes)
        begin
          line = __LINE__ + 1 # as __LINE__ represents next statement line i JRuby, and that becomes difficult to offset
          unit = scripting_container.parse(StringIO.new(<<-"EOS").to_inputstream, __FILE__, line)
            begin
              require 'bundler'
              gemfile, lockfile, groups = Marshal.load(String.from_java_bytes(arguments))
              definition = Bundler::Definition.build(gemfile, lockfile, false)
              ENV['BUNDLE_WITHOUT'] = (definition.groups - groups).join(':')
              specs = definition.specs.map do |gem_spec|
                {
                  :name => gem_spec.name,
                  :full_name => gem_spec.full_name,
                  :full_gem_path => gem_spec.full_gem_path,
                  :load_paths => gem_spec.load_paths,
                  :bindir => gem_spec.bindir,
                }
              end
              Marshal.dump([specs]).to_java_bytes
            rescue => e
              Marshal.dump([nil, e.class, e.message, e.backtrace]).to_java_bytes
            end
          EOS
          result, error, message, backtrace = Marshal.load(String.from_java_bytes(unit.run))
          if error
            raise error, message, Array(backtrace)+caller
          end
          result
        ensure
          scripting_container.terminate
        end
      end
    end
  end
end
