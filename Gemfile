source 'https://rubygems.org'

# Specify your gem's dependencies in storage_strategy.gemspec
gemspec

group :development, :test do
  gem "pry"
  gem "awesome_print"
end

group :test do
  gem "mocha", require: false
  # for code coverage during travis-ci test runs
  gem 'coveralls', require: false
  gem 'rubymine_minitest_spec', git: 'https://github.com/backupify/rubymine_minitest_spec.git'
end
