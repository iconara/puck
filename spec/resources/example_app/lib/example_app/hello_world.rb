# encoding: utf-8

require 'yaml'


module ExampleApp
  class HelloWorld
    def initialize(message)
      @message = message
    end

    def call(env)
      [200, {}, [@message]]]
    end
  end
end