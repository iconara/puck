# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = s.rubyforge_project = 'puck-example_app'
  s.version     = '0.0.1'
  s.platform    = 'java'
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@iconara.net']
  s.homepage    = 'http://github.com/iconara/puck'
  s.summary     = %q{Example application}
  s.description = %q{Example application for Puck}
  s.license     = 'Apache License 2.0'

  s.files              = Dir['lib/**/*.rb', 'bin/*']
  s.require_paths      = %w(lib)
  s.bindir             = 'bin'
  s.default_executable = 'server'
  s.executables        = [s.default_executable]

  s.add_dependency 'regal'
end
