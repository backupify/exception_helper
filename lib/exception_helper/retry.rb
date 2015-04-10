require 'active_support/concern'
require 'active_support/core_ext/module/aliasing'

module ExceptionHelper
  module Retry
    extend ActiveSupport::Concern

    included do
      unless defined?(logger)
        require 'log4r'

        #always return the null logger
        def self.logger
          Log4r::Logger.root
        end
      end
    end

    def retry_on_failure(*exception_list, &block)
      self.class.retry_on_failure(*exception_list, &block)
    end

    def wrap_with_retry(*methods)
      self.class.wrap_with_retry(*methods)
    end

    module ClassMethods
      # execute the given block, retrying only when one of the given exceptions is raised
      def retry_on_failure(*exception_list, &block)
        opts = exception_list.last.is_a?(Hash) ? exception_list.pop : {}
        opts = {:retry_count => 3}.merge(opts)
        retry_count = opts[:retry_count]
        begin
          yield block
        rescue *exception_list => e
          if retry_count > 0
            retry_count -= 1
            logger.info "Exception, trying again #{retry_count} more times"
            sleep opts[:retry_sleep].to_f if opts[:retry_sleep]
            retry
          else
            logger.error "Too many exceptions...re-raising"
            raise
          end
        end
      end

      # Wraps a method with `retry_on_failure` to handle exceptions.  It does this via alias_method_chain,
      # so the original method name will be preserved and the method will simply be decorated with the retry logic.
      def wrap_with_retry(*methods)
        opts = methods.last.is_a?(Hash) ? methods.pop : {}
        exception_list = opts.delete(:exceptions)
        methods.each do |method|
          # Extract the punctuation character from the method name if one exists.
          aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1

          # Create the decorated method that `alias_method_chain` will look for.
          define_method("#{aliased_method}_with_retry#{punctuation}") do |*args|
            retry_on_failure(*exception_list, opts) do
              send("#{aliased_method}_without_retry#{punctuation}", *args)
            end
          end

          # Set up the method chain.
          alias_method_chain method, :retry
        end
      end
    end

  end
end
