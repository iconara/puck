# encoding: utf-8

require 'bundler/setup'
require 'tmpdir'

unless ENV['COVERAGE'] == 'no'
  require 'coveralls'
  require 'simplecov'

  if ENV.include?('TRAVIS')
    Coveralls.wear!
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  end

  SimpleCov.start do
    add_group 'Source', 'lib'
    add_group 'Unit tests', 'spec/puck'
    add_group 'Integration tests', 'spec/integration'
  end
end

require 'puck'