require 'rubygems'

if ENV['CI']
  require 'coveralls'
  Coveralls.wear!
end

require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'minitest/autorun'
require "minitest/reporters"
reporter = ENV['REPORTER']
reporter = case reporter
  when 'none' then nil
  when 'spec' then MiniTest::Reporters::SpecReporter.new
  when 'progress' then MiniTest::Reporters::ProgressReporter.new
  else MiniTest::Reporters::DefaultReporter.new
end
MiniTest::Reporters.use!(reporter) if reporter

require 'gem_logger'
GemLogger.default_logger = Logger.new("/dev/null")

require 'mocha/setup'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'exception_helper'

class TestCase < MiniTest::Spec

  # make minitest spec dsl similar to shoulda
  class << self
    alias :setup :before
    alias :teardown :after
    alias :context :describe
    alias :should :it
  end

  def redefine_constant(constant_name, constant_value)
    constant_class = constant_name.split(/::/)[0..-2].join('::').constantize rescue Object
    constant_variable_name = constant_name.split(/::/).last

    old_value = constant_name.constantize rescue :redef_undefined

    constant_class.send(:remove_const, constant_variable_name.to_sym) unless old_value == :redef_undefined
    constant_class.send(:const_set, constant_variable_name.to_sym, constant_value)

    if block_given?
      begin
        yield
      ensure
        constant_class.send(:remove_const, constant_variable_name.to_sym)
        constant_class.send(:const_set, constant_variable_name.to_sym, old_value) unless old_value == :redef_undefined
      end
    end
  end

end