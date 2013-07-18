# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

require 'puck/version'


Gem::Specification.new do |s|
  s.name        = 'puck'
  s.version     = Puck::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@iconara.net']
  s.homepage    = 'http://github.com/iconara/puck'
  s.summary     = %q{}
  s.description = %q{}

  s.add_dependency 'jruby-jars', "= #{JRUBY_VERSION}"
  s.rubyforge_project = s.name
  
  s.files         = Dir['lib/**/*.rb', 'lib/**/*.jar', 'bin/*']
  s.require_paths = %w(lib)
  s.bindir        = 'bin'
end
