# encoding: utf-8

require 'spec_helper'


module Puck
  describe Jar do
    describe '#create!' do
      def create_jar(dir, options={}, &block)
        FileUtils.cp_r(File.expand_path('../../resources/example_app', __FILE__), @tmp_dir)
        app_dir_path = File.join(dir, 'example_app')
        original_gem_home = ENV['GEM_HOME']
        original_gem_path = ENV['GEM_PATH']
        current_gemset_name = File.read(File.expand_path('../../../.ruby-gemset', __FILE__))
        Dir.chdir(app_dir_path) do
          new_gemset_name = File.read('.ruby-gemset').strip
          ENV['GEM_HOME'] = File.join(File.dirname(original_gem_home), "#{ENV['RUBY_VERSION']}@#{new_gemset_name}")
          ENV['GEM_PATH'] = "#{ENV['GEM_HOME']}:#{ENV['GEM_PATH']}"
          begin
            jar = described_class.new(options)
            jar.create!
          ensure
            ENV['GEM_HOME'] = original_gem_home
            ENV['GEM_PATH'] = original_gem_path
          end
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

      context 'creates a Jar named from the current working dir' do
        before :all do
          @tmp_dir = Dir.mktmpdir
        end

        after :all do
          FileUtils.rm_rf(@tmp_dir)
        end

        context 'with standard options' do
          before :all do
            create_jar(@tmp_dir)
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
            jar_entries.should include('META-INF/gem.home/grape-0.4.1/lib/grape.rb')
            jar_entries.should include('META-INF/gem.home/i18n-0.6.1/lib/i18n.rb')
          end

          it 'correctly handles gems with a specific platform' do
            jar_entries.should include('META-INF/gem.home/puma-2.0.1-java/lib/puma.rb')
          end

          it 'supports git dependencies' do
            jar_entries.should include('META-INF/gem.home/rack-contrib-1.2.0/lib/rack/contrib.rb')
          end

          it 'does not include gems from groups other than "default"' do
            jar_entries.find { |path| path.include?('gem.home/pry') }.should be_nil
            jar_entries.find { |path| path.include?('gem.home/rspec') }.should be_nil
            jar_entries.find { |path| path.include?('gem.home/rack-cache') }.should be_nil
          end

          it 'creates a jar-bootstrap.rb and puts it in the root of the JAR' do
            jar_entries.should include('jar-bootstrap.rb')
          end

          it 'adds all gems to the load path in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%($LOAD_PATH << 'classpath:META-INF/gem.home/grape-0.4.1/lib'))
          end

          it 'adds all gem\'s bin directories to a constant in jar-bootstrap.rb' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(%(PUCK_BIN_PATH << '/META-INF/gem.home/rack-1.5.2/bin'))
          end

          it 'adds each gem only once, even if it is depended on by multiple gems' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.scan(%r{classpath:META-INF/gem.home/rack-1.5.2/lib}).should have(1).item
          end

          it 'adds code that will run the named bin file' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.should include(File.read(File.expand_path('../../../lib/puck/bootstrap.rb', __FILE__)))
          end

          it 'adds gems with other name than repository' do
            bootstrap = jar_entry_contents('jar-bootstrap.rb')
            bootstrap.scan(%r{classpath:META-INF/gem.home/qu-redis-0.2.0/lib}).should have(1).item
          end
        end

        context 'with custom options' do
          it 'includes extra files' do
            create_jar(@tmp_dir, extra_files: %w[config/app.yml])
            jar_entries.should include('META-INF/app.home/config/app.yml')
          end

          it 'uses an alternative jruby-complete.jar' do
            create_jar(@tmp_dir, jruby_complete: File.expand_path('../../resources/fake-jruby-complete.jar', __FILE__))
            jar_entries.should include('META-INF/jruby.home/hello.rb')
            jar_entries.should include('Hello.class')
            jar_entries.should_not include('org/jruby/JarBootstrapMain.class')
            jar_entries.should_not include('META-INF/jruby.home/lib/ruby/1.9/pp.rb')
          end

          it 'includes gems from the specified groups' do
            create_jar(@tmp_dir, gem_groups: [:default, :extra])
            jar_entries.should include('META-INF/gem.home/grape-0.4.1/lib/grape.rb')
            jar_entries.should include('META-INF/gem.home/rack-cache-1.2/lib/rack/cache.rb')
          end
        end
      end
    end
  end
end