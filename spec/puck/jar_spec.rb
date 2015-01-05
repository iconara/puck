# encoding: utf-8

require 'spec_helper'


module Puck
  describe Jar do
    describe '#create!' do
      def create_jar(dir, options={}, &block)
        original_app_dir_path = File.expand_path('../../resources/example_app', __FILE__)
        FileUtils.cp_r(original_app_dir_path, dir)
        app_dir_path = File.join(dir, 'example_app')
        Dir.chdir(app_dir_path) do
          jar = described_class.new(options)
          jar.create!
        end
      end

      def jar
        @jar ||= Java::JavaUtilJar::JarFile.new(Java::JavaIo::File.new(File.join(@tmp_dir, 'example_app/build/example_app.jar')))
      end

      def jar_entries
        jar.entries.to_a.map(&:name)
      end

      def jar_entry_contents(path)
        jar.get_input_stream(jar.get_jar_entry(path)).to_io.read
      end

      class FakeDependencyResolver
        def initialize(base_path)
          @base_path = base_path
        end

        def resolve_gem_dependencies(options)
          [
            {
              :name => 'fake-gem',
              :versioned_name => 'fake-gem-0.1.1',
              :base_path => @base_path,
              :load_paths => %w[fake-gem-0.1.1/lib],
              :bin_path => %'fake-gem-0.1.1/bin',
            },
            {
              :name => 'example_app',
              :versioned_name => 'example_app-0.0.0',
              :base_path => File.expand_path('.'),
              :load_paths => %w[example_app-0.0.0/lib],
              :bin_path => 'example_app-0.0.0/bin',
            }
          ]
        end
      end

      before :all do
        @fake_gem_dir = Dir.mktmpdir
        Dir.chdir(@fake_gem_dir) do
          Dir.mkdir('bin')
          File.write('bin/fake', 'require "fake"')
          Dir.mkdir('lib')
          File.write('lib/fake.rb', 'exit 2')
        end
      end

      context 'creates a Jar named from the current working dir' do
        before :all do
          @tmp_dir = Dir.mktmpdir
        end

        after :all do
          FileUtils.rm_rf(@tmp_dir)
        end

        context 'with standard options' do
          before :all do
            create_jar(@tmp_dir, dependency_resolver: FakeDependencyResolver.new(@fake_gem_dir))
          end

          it 'sets the Main-Class attribute to JarBootstrapMain' do
            manifest = jar_entry_contents('META-INF/MANIFEST.MF')
            manifest.should include('Main-Class: org.jruby.JarBootstrapMain')
          end

          it 'sets the Created-By attribute to Puck' do
            manifest = jar_entry_contents('META-INF/MANIFEST.MF')
            manifest.should match(/Created-By: Puck v[\d.]+/)
          end

          it 'puts the project code in META-INF/app.home' do
            jar_entries.should include('META-INF/app.home/lib/example_app.rb')
          end

          it 'includes the project\'s bin dir' do
            jar_entries.should include('META-INF/app.home/bin/server')
          end

          it 'includes the JRuby core' do
            jar_entries.should include('org/jruby/JarBootstrapMain.class')
          end

          it 'includes the Ruby stdlib' do
            jar_entries.should include('META-INF/jruby.home/lib/ruby/1.9/pp.rb')
          end

          it 'puts gems into META-INF/gem.home' do
            jar_entries.should include('META-INF/gem.home/fake-gem-0.1.1/bin/fake')
            bin = jar_entry_contents('META-INF/gem.home/fake-gem-0.1.1/bin/fake')
            bin.should == 'require "fake"'
            jar_entries.should include('META-INF/gem.home/fake-gem-0.1.1/lib/fake.rb')
            lib = jar_entry_contents('META-INF/gem.home/fake-gem-0.1.1/lib/fake.rb')
            lib.should == 'exit 2'
          end

          it 'does not bundle the project as a gem, as it should already be included' do
            jar_entries.should_not include('META-INF/gem.home/example_app-0.0.0/bin/server')
            jar_entries.should_not include('META-INF/gem.home/example_app-0.0.0/lib/example_app.rb')
          end

          it 'creates a jar-bootstrap.rb and puts it in the root of the JAR' do
            jar_entries.should include('jar-bootstrap.rb')
          end

          it 'adds all gems to the load path in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%($LOAD_PATH << 'classpath:META-INF/gem.home/fake-gem-0.1.1/lib'))
          end

          it 'adds all gem\'s bin directories to a constant in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%(PUCK_BIN_PATH << '/META-INF/gem.home/fake-gem-0.1.1/bin'))
          end

          it 'adds code that will run the named bin file' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(File.read(File.expand_path('../../../lib/puck/bootstrap.rb', __FILE__)))
          end
        end

        context 'with custom options' do
          let :dependency_resolver do
            FakeDependencyResolver.new(@fake_gem_dir)
          end

          it 'includes extra files' do
            create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: %w[config/app.yml])
            jar_entries.should include('META-INF/app.home/config/app.yml')
          end

          it 'uses an alternative jruby-complete.jar' do
            create_jar(@tmp_dir, dependency_resolver: dependency_resolver, jruby_complete: File.expand_path('../../resources/fake-jruby-complete.jar', __FILE__))
            jar_entries.should include('META-INF/jruby.home/hello.rb')
            jar_entries.should include('Hello.class')
            jar_entries.should_not include('org/jruby/JarBootstrapMain.class')
            jar_entries.should_not include('META-INF/jruby.home/lib/ruby/1.9/pp.rb')
          end

          it 'includes gems from the specified groups' do
            dependency_resolver.should_receive(:resolve_gem_dependencies).with(hash_including(gem_groups: [:default, :extra])).and_return([])
            create_jar(@tmp_dir, dependency_resolver: dependency_resolver, gem_groups: [:default, :extra])
          end
        end
      end
    end
  end
end