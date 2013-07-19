# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'bin/puck' do
  it 'creates a self-contained Jar' do
    done = false
    result = nil
    thread = Thread.start do
      command = [
        'cd spec/resources/example_app',
        'rm -rf build',
        'rvm ${RUBY_VERSION}@$(cat .ruby-gemset) do bundle exec puck --extra-files config/app.yml',
        'GEM_HOME= GEM_PATH= java -jar build/example_app.jar server',
      ]
      pid = Process.spawn(command.join(' && '), stdout: $stdout, stderr: $stderr)
      sleep 5 until done
      Process.kill('HUP', pid)
    end
    attempts_remaning = 10
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
end
