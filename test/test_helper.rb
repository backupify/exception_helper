require "rubygems"

if ENV["CI"]
  require "coveralls"
  Coveralls.wear!
end

require "bundler"

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require "minitest/autorun"
require "minitest/reporters"
require "mocha/setup"
require "exception_helper"

module ExceptionHelper
  class TestCase < MiniTest::Spec

    # make minitest spec dsl similar to shoulda
    class << self
      alias :setup :before
      alias :teardown :after
      alias :context :describe
      alias :should :it
    end
  end
end
