# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

require 'jarbler/version'


Gem::Specification.new do |s|
  s.name        = 'jarbler'
  s.version     = Jarbler::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@iconara.net']
  s.homepage    = 'http://github.com/iconara/jarbler'
  s.summary     = %q{}
  s.description = %q{}

  s.add_dependency 'jruby-jars', "= #{JRUBY_VERSION}"
  s.rubyforge_project = s.name
  
  s.files         = Dir['lib/**/*.rb'] + Dir['lib/**/*.jar']
  s.require_paths = %w(lib)
end
