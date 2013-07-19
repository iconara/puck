# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'bin/puck' do
  let :jar_command do
    %(GEM_HOME='' GEM_PATH='' java -jar spec/resources/example_app/build/example_app.jar)
  end

  before :all do
    system([
      'cd spec/resources/example_app',
      'rm -rf build',
      'BUNDLE_GEMFILE=$(pwd)/Gemfile rvm ${RUBY_VERSION}@$(cat .ruby-gemset) do bundle exec puck --extra-files config/app.yml',
    ].join(' && '))
  end

  it 'creates a self-contained Jar that exposes the app\'s bin files' do
    done = false
    result = nil
    thread = Thread.start do
      pid = Process.spawn("#{jar_command} server")
      sleep 5 until done
      Process.kill('HUP', pid)
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
    result.should_not be_nil
  end

  it 'outputs an error when the named script can\'t be found' do
    output = %x(#{jar_command} xyz 2>&1)
    output.should include('No "xyz" in /META-INF/app.home/bin:/META-INF/jruby.home/bin:/META-INF/gem.home/puma-2.0.1-java/bin:')
  end

  it 'exposes JRuby\'s bin files' do
    output = %x(#{jar_command} irb -h 2>&1)
    output.should include('Usage:  irb.rb')
  end

  it 'exposes all gem\'s bin files' do
    output = %x(#{jar_command} rackup -h 2>&1)
    output.should include('Usage: rackup')
  end
end
