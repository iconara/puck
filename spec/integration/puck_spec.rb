# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'bin/puck' do
  APP_DIR = File.expand_path('../../resources/example_app', __FILE__)

  def isolated_run(cmd)
    Dir.chdir(APP_DIR) do
      `#{cmd}`
    end
  end

  def jar_command(cmd)
    sprintf('java -jar build/example_app.jar %s 2>&1', cmd)
  end

  before :all do
    isolated_run("rm -rf build && BUNDLE_GEMFILE=Gemfile BUNDLE_PATH=../../../vendor/example_app-bundle/jruby/1.9 BUNDLE_WITHOUT=not_installed .bundle/bin/puck --extra-files config/app.yml")
  end

  it 'creates a self-contained Jar that exposes the app\'s bin files' do
    done = false
    result = nil
    thread = Thread.start do
      Dir.chdir(APP_DIR) do
        pid = Process.spawn(jar_command('server'))
        sleep 5 until done
        Process.kill('HUP', pid)
      end
    end
    attempts_remaning = 20
    loop do
      begin
        result = open('http://127.0.0.1:3344/').read
        break
      rescue => e
        attempts_remaning -= 1
        if attempts_remaning > 0
          sleep 5
        else
          break
        end
      end
    end
    done = true
    thread.join
    result.should eq("server: Hello World")
  end

  it 'outputs an error when the named script can\'t be found' do
    output = isolated_run(jar_command('xyz'))
    output.should match(%r{No "xyz" in META-INF/app.home/bin:META-INF/jruby.home/bin:META-INF/gem.home/})
  end

  it 'exposes JRuby\'s bin files' do
    output = isolated_run(jar_command('irb -h'))
    output.should include('Usage:  irb.rb')
  end

  it 'exposes all gem\'s bin files' do
    output = isolated_run(jar_command('rackup -h'))
    output.should include('Usage: rackup')
  end
end
