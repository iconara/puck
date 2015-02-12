# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

require 'puck/version'


Gem::Specification.new do |s|
  s.name        = s.rubyforge_project = 'puck'
  s.version     = Puck::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@iconara.net']
  s.homepage    = 'http://github.com/iconara/puck'
  s.summary     = %q{Packs your JRuby app as a standalone Jar file}
  s.description = %q{Puck takes your app and packs it along with all your gems and a complete JRuby runtime in a standalone Jar file that can be run with just `java -jar …`}
  s.license     = 'Apache License 2.0'

  s.files              = Dir['lib/**/*.rb', 'bin/puck', '.yardopts']
  s.require_paths      = %w(lib)
  s.bindir             = 'bin'
  s.default_executable = s.name
  s.executables        = [s.default_executable]
end
