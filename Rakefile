# encoding: utf-8

require 'bundler'
require 'bundler/setup'
require 'rspec/core/rake_task'


task :setup do
  system('bin/setup')
end

RSpec::Core::RakeTask.new(:spec) do |r|
  r.rspec_opts = '--tty'
end

task :spec => :setup

Bundler::GemHelper.install_tasks
