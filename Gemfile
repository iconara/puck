source 'https://rubygems.org/'

gemspec

group :development do
  gem 'pry'
  gem 'travis-lint'
  gem 'yard'
  gem 'kramdown'
  gem 'rake'
end

group :test do
  gem 'jruby-jars', '= 1.7.12'
  gem 'rspec', '~> 2.14', '< 2.99'
  gem 'simplecov'
end

group :coveralls do
  gem 'coveralls'
  if RUBY_VERSION < '2'
    gem 'term-ansicolor', '~> 1.3.0'
    gem 'tins', '~> 1.6.0'
  end
end
