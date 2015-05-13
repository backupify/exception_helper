require 'active_support/concern'
require 'active_support/core_ext/module/aliasing'

module ExceptionHelper
  module Retry
    extend ActiveSupport::Concern
    include GemLogger::LoggerSupport

    # @see ClassMethods#retry_on_failure
    def retry_on_failure(*args, &block)
      self.class.retry_on_failure(*args, &block)
    end

    # @see ClassMethods#retry_on_failure_except
    def retry_on_failure_except(*args, &block)
      self.class.retry_on_failure_except(*args, &block)
    end

    # @see ClassMethods#retry_on_failure_condition
    def retry_on_failure_condition(condition, opts = {}, &block)
      self.class.retry_on_failure_condition(condition, opts, &block)
    end

    module ClassMethods
      # execute the given block, retrying only when one of the given exceptions is raised
      # @param [Array] args - exceptions to retry on, last element should be a Hash of options
      #
      # @option opts [Integer] :retry_count Number of times to retry after any of the specified exceptions
      # @option opts [Integer] :retry_sleep Number of seconds to wait before retrying again
      # @option opts [Boolean] :exponential_backoff Whether or not to use exponential back off when sleeping.  This will invalidate any retry_sleep value
      # @option opts [Boolean] :log_retries Whether or not to log a message on each retry. Default true.
      # @option opts [Integer] :jitter Maximum amount randomness to add to each retry sleep in milliseconds. Default 1000ms
      def retry_on_failure(*args, &block)
        opts = remove_opts_from_args(args)
        exception_list = args

        retry_block_on_failure(opts, is_exception_in_list_lambda(exception_list)) do
          yield
        end
      end

      # execute the given block, retrying only when the exception raised is NOT one of the given exceptions
      # @param [Array] args - exceptions not to retry on, last element should be a Hash of options
      #
      # @option opts [Integer] :retry_count Number of times to retry after any of the specified exceptions
      # @option opts [Integer] :retry_sleep Number of seconds to wait before retrying again
      # @option opts [Boolean] :exponential_backoff Whether or not to use exponential back off when sleeping.  This will invalidate any retry_sleep value
      # @option opts [Boolean] :log_retries Whether or not to log a message on each retry. Default true.
      # @option opts [Integer] :jitter Maximum amount randomness to add to each retry sleep in milliseconds. Default 1000ms
      def retry_on_failure_except(*args, &block)
        opts = remove_opts_from_args(args)
        exception_list = args

        retry_block_on_failure(opts, lambda {|e| !is_exception_in_list_lambda(exception_list).call(e) }) do
          yield
        end
      end

      # execute the given block, retrying only when the exception raised is NOT one of the given exceptions
      # @param [Lambda] condition - lambda expression which, when called with an exception, returns true if
      #   we should retry on the exception.
      # @param [Hash] opts - described below
      #
      # @option opts [Integer] :retry_count Number of times to retry after any of the specified exceptions
      # @option opts [Integer] :retry_sleep Number of seconds to wait before retrying again
      # @option opts [Boolean] :exponential_backoff Whether or not to use exponential back off when sleeping.  This will invalidate any retry_sleep value
      # @option opts [Boolean] :log_retries Whether or not to log a message on each retry. Default true.
      # @option opts [Integer] :jitter Maximum amount randomness to add to each retry sleep in milliseconds. Default 1000ms
      def retry_on_failure_condition(condition, opts = {}, &block)
        retry_block_on_failure(opts, condition) do
          yield
        end
      end

      private

      def retry_block_on_failure(opts, should_retry_lamba)
        opts = {:retry_count => 3, :log_retries => true}.merge(opts)
        retry_count = retries_remaining = opts[:retry_count]
        log_retries = opts[:log_retries]

        exponential_backoff = opts[:exponential_backoff]
        # If exponential back off is enabled, we always want to start with 1
        retry_sleep = exponential_backoff ? 1 : opts[:retry_sleep]
        retry_id = SecureRandom.uuid
        retry_start = Time.now.to_f

        begin
          result = yield
          if log_retries && retries_remaining != retry_count
            retries_required = retry_count - retries_remaining
            log_retry_success(retry_id, retries_required, retry_start)
          end
          result
        rescue => e
          raise unless should_retry_lamba.call(e)

          if retries_remaining <= 0
            log_retry_failure(retry_id, e, retry_count, retry_start)
            raise
          end


          if retry_sleep && (!defined?(DISABLE_EXCEPTION_RETRY_SLEEP) || DISABLE_EXCEPTION_RETRY_SLEEP == false)
            # generate random jitter up to specified value in seconds.
            jitter = Random.rand(opts[:jitter] || 1000) / 1000.0
            sleep_time = retry_sleep + jitter
            retry_sleep = retry_sleep * 2 if exponential_backoff
          end

          if log_retries
            log_retry_attempt(retry_id, e, retries_remaining, retry_start, sleep_time)
          end

          retries_remaining -= 1
          sleep sleep_time if sleep_time

          retry
        end
      end

      def log_retry_attempt(retry_id, exception, retries_remaining, retry_start, sleep_time = nil)
        time_elapsed = Time.now.to_f - retry_start
        logger.event_context(:retry_exception_attempt).context({
          :exception => exception.class.name,
          :message => exception.message,
          :retries_remaining => retries_remaining,
          :retry_id => retry_id,
          :sleep_before_retry => sleep_time,
          :time_elapsed => time_elapsed,
        }).warn("")
      end

      def log_retry_failure(retry_id, exception, retries_attempted, retry_start)
        time_elapsed = Time.now.to_f - retry_start
        logger.event_context(:retry_exception_failure).context({
          :exception => exception.class.name,
          :message => exception.message,
          :retries_attempted => retries_attempted,
          :retry_id => retry_id,
          :time_elapsed => time_elapsed,
        }).error("")
      end

      def log_retry_success(retry_id, retries_required, retry_start)
        time_elapsed = Time.now.to_f - retry_start
        logger.event_context(:retry_exception_success).context({
          :retries_required => retries_required,
          :retry_id => retry_id,
          :time_elapsed => time_elapsed,
        }).info("")
      end

      def remove_opts_from_args(args)
        args.last.is_a?(Hash) ? args.pop : {}
      end

      def is_exception_in_list_lambda(exception_list)
        lambda { |e|
          exception_list.inject(false) {|result, cur| result || e.is_a?(cur)}
        }
      end

    end

  end
end
