# encoding: utf-8

require 'spec_helper'


module Puck
  describe DependencyResolver do
    describe '#resolve_gem_dependencies' do
      let :resolved_gem_dependencies do
        Bundler.with_clean_env do
          scripting_container = Java::OrgJrubyEmbed::ScriptingContainer.new(Java::OrgJrubyEmbed::LocalContextScope::SINGLETHREAD)
          scripting_container.compat_version = Java::OrgJruby::CompatVersion::RUBY1_9
          scripting_container.environment = ENV.merge('GEM_HOME' => gem_home, 'GEM_PATH' => "#{gem_home}:#{ENV['GEM_PATH']}")
          scripting_container.load_paths += [File.expand_path('../../../lib', __FILE__)]
          marshaled = scripting_container.run_scriptlet <<-"EOS"
            Dir.chdir(#{app_dir_path.inspect}) do
              require "puck/dependency_resolver"
              dependency_resolver = #{described_class}.new
              result = dependency_resolver.resolve_gem_dependencies(#{options.inspect})
              Marshal.dump(result)
            end
          EOS
          Marshal.load(marshaled)
        end
      end

      let :app_dir_path do
        File.expand_path('../../resources/example_app', __FILE__)
      end

      let :gem_home do
        gemset_name = File.read(File.join(app_dir_path, '.ruby-gemset')).strip
        File.join(ENV['HOME'], '.rvm', 'gems', "#{ENV['RUBY_VERSION']}@#{gemset_name}")
      end

      let :options do
        {}
      end

      let :tmp_dir do
        Dir.mktmpdir
      end

      after do
        FileUtils.rm_rf(tmp_dir)
      end

      it 'includes the gem name in the specification' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should include('grape')
        gem_names.should include('i18n')
      end

      it 'includes the versioned gem name in the specification' do
        versioned_gem_names = resolved_gem_dependencies.map { |gem| gem[:versioned_name] }
        versioned_gem_names.should include('grape-0.4.1')
        versioned_gem_names.should include('i18n-0.6.1')
      end

      it 'includes the gem\'s base path in the specification' do
        base_paths = resolved_gem_dependencies.map { |gem| Pathname.new(gem[:base_path]) }
        base_paths.first.should be_directory
      end

      it 'includes version-name qualified loads paths in the specification' do
        load_paths = resolved_gem_dependencies.flat_map { |gem| gem[:load_paths] }
        load_paths.should include('grape-0.4.1/lib')
        load_paths.should include('i18n-0.6.1/lib')
      end

      it 'includes the version-name qualified bin path in the specification' do
        load_paths = resolved_gem_dependencies.map { |gem| gem[:bin_path] }
        load_paths.should include('grape-0.4.1/bin')
        load_paths.should include('i18n-0.6.1/bin')
      end

      it 'correctly handles gems with a specific platform' do
        specification = resolved_gem_dependencies.find { |gem| gem[:name] == 'puma' }
        File.basename(specification[:base_path]).should == 'puma-2.0.1-java'
      end

      it 'supports git dependencies' do
        specification = resolved_gem_dependencies.find { |gem| gem[:name] == 'rack-contrib' }
        specification[:load_paths].should include('rack-contrib-1.2.0/lib')
      end

      it 'only includes gems from the "default" group by default' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should_not include('pry', 'rspec', 'rack-cache')
      end

      it 'returns each gem only once, even if it is a dependency of multiple gems' do
        specifications = resolved_gem_dependencies.select { |gem| gem[:name] == 'rack' }
        specifications.should have(1).specification
      end

      it 'supports gems with names that are not the same as the repository they are installed from' do
        specifications = resolved_gem_dependencies.select { |gem| gem[:name] == 'qu-redis' }
        specifications.should have(1).specification
      end

      context 'with custom groups' do
        let :options do
          super.merge(gem_groups: [:default, :extra])
        end

        it 'includes gems from the specified groups' do
          gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
          gem_names.should include('grape', 'rack-cache')
        end
      end
    end
  end
end