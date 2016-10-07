# encoding: utf-8

require 'bundler/setup'
require 'tmpdir'
require 'support/rewind_in_jars'

unless ENV['COVERAGE'] == 'no' || ENV.include?('TRAVIS')
  require 'simplecov'

  SimpleCov.start do
    add_group 'Source', 'lib'
    add_group 'Unit tests', 'spec/puck'
    add_group 'Integration tests', 'spec/integration'
  end
end

require 'puck'
