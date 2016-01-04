# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = s.rubyforge_project = 'puck-example_dep'
  s.version     = '0.0.1'
  s.platform    = 'java'
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@iconara.net']
  s.homepage    = 'http://github.com/iconara/puck'
  s.summary     = %q{Example dependency}
  s.description = %q{Example dependency for Puck example application}
  s.license     = 'Apache License 2.0'

  s.files              = Dir['lib/**/*.rb']
  s.require_paths      = %w(lib)
end
