# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'bin/puck' do
  it 'creates a self-contained Jar' do
    done = false
    thread = Thread.start do
      command = [
        'cd spec/resources/example_app',
        'rvm ${RUBY_VERSION}@$(cat .ruby-gemset) do ../../../bin/puck --extra-files config/app.yml',
        'GEM_HOME= GEM_PATH= java -jar build/example_app.jar server',
      ]
      pid = Process.spawn(command.join(' && '), stdout: $stdout, stderr: $stderr)
      sleep 5 until done
      Process.kill('HUP', pid)
    end
    loop do
      begin
        open('http://127.0.0.1:3344/').read
        break
      rescue => e
        sleep 5
      end
    end
    done = true
    thread.join
  end
end
