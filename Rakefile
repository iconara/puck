# encoding: utf-8

require 'bundler'
require 'bundler/setup'
require 'rspec/core/rake_task'

EXAMPLE_APP_BUNDLE_PATH = File.expand_path('../vendor/example_app-bundle', __FILE__)
EXAMPLE_APP_HOME = File.expand_path('../spec/resources/example_app', __FILE__)

task :setup do
  Bundler.clean_system("bundle install --without=not_installed --retry=3 --gemfile=#{EXAMPLE_APP_HOME}/Gemfile --path=#{EXAMPLE_APP_BUNDLE_PATH} --binstubs=#{EXAMPLE_APP_HOME}/.bundle/bin")
  rm_rf File.join(EXAMPLE_APP_HOME, '.bundle/config')
end

task :clean do
  [File.join(EXAMPLE_APP_HOME, '.bundle'), EXAMPLE_APP_BUNDLE_PATH].each do |path|
    rm_rf(path)
  end
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
