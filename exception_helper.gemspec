# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'exception_helper/version'

Gem::Specification.new do |gem|
  gem.name          = "exception_helper"
  gem.version       = ExceptionHelper::VERSION
  gem.authors       = ["Jason Haruska"]
  gem.email         = ["jason@haruska.com"]
  gem.description   = %q{Common mixins for handling exceptions}
  gem.summary       = %q{Common mixins for handling exceptions including retries.}
  gem.homepage      = "https://github.com/backupify/exception_helper"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake"
  gem.add_development_dependency "shoulda"
  gem.add_development_dependency "bundler"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "log4r"
end


