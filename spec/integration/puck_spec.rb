# encoding: utf-8

require 'spec_helper'
require 'open-uri'
require 'fileutils'

describe 'bin/puck' do
  APP_DIR = File.expand_path('../../resources/example_app', __FILE__)

  def isolated_run(cmd)
    Dir.chdir(APP_DIR) do
      Bundler.with_clean_env do
        IO.popen(cmd, 'r', &:read)
      end
    end
  end

  def jar_command(cmd)
    sprintf('exec java -jar build/example_app.jar %s 2>&1', cmd)
  end

  before :all do
    FileUtils.rm_rf File.join(APP_DIR, 'build')
    env = {
      'BUNDLE_GEMFILE' => 'Gemfile',
      'GEM_HOME' => File.join('vendor/bundle/jruby', RbConfig::CONFIG['ruby_version']),
      'BUNDLE_PATH' => File.join('vendor/bundle/jruby', RbConfig::CONFIG['ruby_version']),
      'BUNDLE_WITHOUT' => 'not_installed',
    }
    isolated_run([env, '.bundle/bin/puck', '--extra-files', 'config/app.yml', '--merge-archives', '../../resources/fake-external.jar'])
  end

  it 'creates a self-contained Jar that exposes the app\'s bin files' do
    done = Java::JavaUtilConcurrent::Semaphore.new(0)
    stopped = Java::JavaUtilConcurrent::Semaphore.new(0)
    seconds = Java::JavaUtilConcurrent::TimeUnit::SECONDS
    result = nil
    thread = Thread.start do
      Dir.chdir(APP_DIR) do
        begin
          pid = Bundler.with_clean_env do
            Process.spawn(jar_command('server'))
          end
          until done.try_acquire(1, seconds)
            Process.kill(0, pid)
          end
          Process.kill('HUP', pid)
          Process.wait(pid) rescue nil
        ensure
          stopped.release
        end
      end
    end
    attempts_remaning = 100
    loop do
      begin
        result = open('http://127.0.0.1:3344/').read
        break
      rescue => e
        attempts_remaning -= 1
        if attempts_remaning == 0 || stopped.try_acquire(1, seconds)
          break
        end
      end
    end
    done.release
    thread.join
    result.should eq("server: Hello World")
  end

  it 'outputs an error when the named script can\'t be found' do
    output = isolated_run(jar_command('xyz'))
    output.should match(%r{No "xyz" in META-INF/app.home/bin:META-INF/jruby.home/bin:META-INF/gem.home/})
  end

  it 'exposes JRuby\'s bin files' do
    output = isolated_run(jar_command('gem -h'))
    output.should include('gem -h/--help')
  end

  it "runs bin files that require embedded files to be rewindable (current behavior: #{RewindInJars.behavior_after_gets})" do
    pending 'not supported', if: RewindInJars.behavior_after_gets == :discard do
      output = isolated_run(jar_command('irb -h'))
      output.should include('Usage:  irb.rb')
    end
  end

  it 'exposes all gem\'s bin files' do
    output = isolated_run(jar_command('rackup -h'))
    output.should include('Usage: rackup')
  end

  it 'is possible to find specific versions of gems with Kernel#gem' do
    gem_command = 'gem("json", "=1.8.1")'
    output = isolated_run(sprintf("echo '%s' | %s", gem_command, jar_command('irb')))
    output.should include(sprintf("%s\ntrue\n", gem_command))
  end
end
