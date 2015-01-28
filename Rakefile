# encoding: utf-8

require 'bundler'
require 'bundler/setup'
require 'rspec/core/rake_task'


task :setup do
  Bundler.clean_system('bin/setup')
end

RSpec::Core::RakeTask.new(:spec) do |r|
  r.rspec_opts = '--tty'
end

task :spec => :setup

namespace :gem do
  Bundler::GemHelper.install_tasks
end

desc 'Release a new gem version'
task :release => [:spec, 'gem:release']
Bundler::GemHelper.install_tasks
