# encoding: utf-8

require 'spec_helper'


module Puck
  describe Jar do
    describe '#create' do
      def create_jar(dir, options={}, &block)
        original_app_dir_path = File.expand_path('../../resources/example_app', __FILE__)
        FileUtils.cp_r(original_app_dir_path, dir)
        app_dir_path = File.join(dir, 'example_app')
        Dir.chdir(app_dir_path) do
          jar = described_class.new(options)
          output_path = jar.create
          FileUtils.cp(output_path, @tmp_dir)
        end
      end

      def jar
        @jar ||= Java::JavaUtilJar::JarFile.new(Java::JavaIo::File.new(File.join(@tmp_dir, 'example_app.jar')))
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
              :load_paths => %w[lib],
              :bin_path => 'bin',
              :spec_file => File.join(@base_path, 'fake-gem.gemspec'),
            },
            {
              :name => 'example_app',
              :versioned_name => 'example_app-0.0.0',
              :base_path => File.expand_path('.'),
              :load_paths => %w[lib],
              :bin_path => 'bin',
              :spec_file => File.expand_path('example-app.gemspec'),
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
          File.write('fake-gem.gemspec', '')
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

          it 'puts gems into META-INF/gem.home/gems' do
            jar_entries.should include('META-INF/gem.home/gems/fake-gem-0.1.1/bin/fake')
            bin = jar_entry_contents('META-INF/gem.home/gems/fake-gem-0.1.1/bin/fake')
            bin.should == 'require "fake"'
            jar_entries.should include('META-INF/gem.home/gems/fake-gem-0.1.1/lib/fake.rb')
            lib = jar_entry_contents('META-INF/gem.home/gems/fake-gem-0.1.1/lib/fake.rb')
            lib.should == 'exit 2'
          end

          it 'puts gemspecs into META-INF/gem.home/specifications' do
            jar_entries.should include('META-INF/gem.home/specifications/fake-gem.gemspec')
          end

          it 'does not bundle the project as a gem, as it should already be included' do
            jar_entries.grep(%r{META-INF/gem.home/gems/example_app-}).should be_empty
          end

          it 'creates a jar-bootstrap.rb and puts it in the root of the JAR' do
            jar_entries.should include('jar-bootstrap.rb')
          end

          it 'sets GEM_HOME in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%|Gem.paths = {'GEM_HOME' => File.join(PUCK_ROOT, 'META-INF/gem.home')}|)
          end

          it 'adds all gem\'s bin directories to a constant in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%(PUCK_BIN_PATH << 'META-INF/gem.home/gems/fake-gem-0.1.1/bin'))
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

          before do
            FileUtils.rm_rf(@tmp_dir)
            @tmp_dir = Dir.mktmpdir
          end

          context 'with extra files' do
            context 'when the argument is an array' do
              it 'preserves relative paths' do
                create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: %w[config/app.yml])
                jar_entries.should include('META-INF/app.home/config/app.yml')
              end

              it 'is possible to include files using globs' do
                create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: %w[config/*.yml])
                jar_entries.should include('META-INF/app.home/config/app.yml', 'META-INF/app.home/config/another.yml')
              end
            end

            context 'when the argument is a hash' do
              it 'uses the keys for the path of the content and the value as the path within the JAR' do
                create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: {'config/app.yml' => 'specified/path.yml'})
                jar_entries.should include('specified/path.yml')
              end

              it 'is not possible to include files using globs' do
                expect { create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: {'config/*.yml' => 'specified/path.yml'}) }.to raise_error(PuckError)
              end

              context 'when the value is nil' do
                it 'preserves relative paths' do
                  create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: {'config/app.yml' => nil})
                  jar_entries.should include('META-INF/app.home/config/app.yml')
                end

                it 'is possible to include files using globs' do
                  create_jar(@tmp_dir, dependency_resolver: dependency_resolver, extra_files: {'config/*.yml' => nil})
                  jar_entries.should include('META-INF/app.home/config/app.yml', 'META-INF/app.home/config/another.yml')
                end
              end
            end

            context 'with merge archives' do
              context 'when the argument is an array' do
                it 'merges the archives and preserves their relative paths' do
                  create_jar(@tmp_dir, dependency_resolver: dependency_resolver, merge_archives: [File.expand_path('../../resources/fake-external.jar', __FILE__)])
                  jar_entries.should include('fake-external/foo.class')
                  jar_entries.should include('fake-external/bar.class')
                end
              end

              context 'when the argument is a hash' do
                it 'merges the archives and uses the keys for the path of the content and the value as the path within the JAR' do
                  create_jar(@tmp_dir, dependency_resolver: dependency_resolver, merge_archives: { File.expand_path('../../resources/fake-external.jar', __FILE__) => 'specified/path' })
                  jar_entries.should include('specified/path/fake-external/foo.class')
                  jar_entries.should include('specified/path/fake-external/bar.class')
                end
              end

              it 'does not merge signature files' do
                create_jar(@tmp_dir, dependency_resolver: dependency_resolver, merge_archives: [File.expand_path('../../resources/fake-external.jar', __FILE__)])
                jar_entries.should_not include('META-INF/foo.SF')
                jar_entries.should_not include('META-INF/foo.RSA')
                jar_entries.should_not include('META-INF/foo.DSA')
                jar_entries.should_not include('META-INF/SIG-nature.txt')
              end
            end
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

          context 'when JRubyJars could not be loaded and no alternative JRuby Jar is provided' do
            it 'raises an error' do
              const = Object.send(:remove_const, :JRubyJars)
              expect { create_jar(@tmp_dir, dependency_resolver: FakeDependencyResolver.new(@fake_gem_dir)) }.to raise_error(PuckError)
              Object.const_set(:JRubyJars, const)
            end
          end
        end
      end
    end
  end
end