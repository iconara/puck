# encoding: utf-8

module ExampleApp
  class HelloWorld
    def call(env)
      [200, {}, ['Hello World']]
    end
  end
end