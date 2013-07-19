# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'bin/puck' do
  before :all do
    system([
      'cd spec/resources/example_app',
      'rm -rf build',
      'BUNDLE_GEMFILE=$(pwd)/Gemfile rvm ${RUBY_VERSION}@$(cat .ruby-gemset) do bundle exec puck --extra-files config/app.yml',
    ].join(' && '))
  end

  it 'creates a self-contained Jar' do
    done = false
    result = nil
    thread = Thread.start do
      pid = Process.spawn('GEM_HOME="" GEM_PATH="" java -jar spec/resources/example_app/build/example_app.jar server', stdout: $stdout, stderr: $stderr)
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

  it 'exposes all gem\'s bin files' do
    output = %x(GEM_HOME="" GEM_PATH="" java -jar spec/resources/example_app/build/example_app.jar rackup -h 2>&1)
    output.should include('Usage: rackup')
  end
end
