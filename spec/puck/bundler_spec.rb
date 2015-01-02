# encoding: utf-8

require 'spec_helper'


module Puck
  describe Bundler do
    describe '#resolve_gem_dependencies' do
      let :resolved_gem_dependencies do
        app_dir_path = File.expand_path('../../resources/example_app', __FILE__)
        gemset_name = File.read(File.join(app_dir_path, '.ruby-gemset')).strip
        original_gem_home = ENV['GEM_HOME']
        original_gem_path = ENV['GEM_PATH']
        ENV['GEM_HOME'] = File.join(ENV['HOME'], '.rvm', 'gems', "#{ENV['RUBY_VERSION']}@#{gemset_name}")
        ENV['GEM_PATH'] = "#{ENV['GEM_HOME']}:#{ENV['GEM_PATH']}"
        begin
          Dir.chdir(app_dir_path) do
            bundler = described_class.new
            bundler.resolve_gem_dependencies(options)
          end
        ensure
          ENV['GEM_HOME'] = original_gem_home
          ENV['GEM_PATH'] = original_gem_path
        end
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

      it 'includes gem name in specification' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should include('grape')
        gem_names.should include('i18n')
      end

      it 'includes gem versioned names in specification' do
        versioned_gem_names = resolved_gem_dependencies.map { |gem| gem[:versioned_name] }
        versioned_gem_names.should include('grape-0.4.1')
        versioned_gem_names.should include('i18n-0.6.1')
      end

      it 'includes gem base path in specification' do
        base_paths = resolved_gem_dependencies.map { |gem| Pathname.new(gem[:base_path]) }
        base_paths.first.should be_directory
      end

      it 'includes version-name qualified loads paths in specification' do
        load_paths = resolved_gem_dependencies.flat_map { |gem| gem[:load_paths] }
        load_paths.should include('grape-0.4.1/lib')
        load_paths.should include('i18n-0.6.1/lib')
      end

      it 'includes version-name qualified bin paths in specification' do
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

      it 'does not include gems from groups other than "default"' do
        gem_names = resolved_gem_dependencies.map { |gem| gem[:name] }
        gem_names.should_not include('pry', 'rspec', 'rack-cache')
      end

      it 'returns each gem only once, even if it is depended on by multiple gems' do
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