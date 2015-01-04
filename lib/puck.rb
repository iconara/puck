# encoding: utf-8

module Puck
  PuckError = Class.new(StandardError)
  GemNotFoundError = Class.new(PuckError)
end

require 'puck/configuration'
require 'puck/dependency_resolver'
require 'puck/jar'