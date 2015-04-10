require "test_helper"

class ExceptionHelper::RetryTest < ExceptionHelper::TestCase
  Subject = self

  include ExceptionHelper::Retry

  class TestException1 < Exception
  end

  class TestException2 < Exception
  end

  should "have no impact on passing code" do
    expects(:puts).with("hello").once
    retry_on_failure(TestException1) do
      puts "hello"
    end
  end

  should "retry for specified exceptions" do
    expects(:puts).with("hello").at_least(2)
    assert_raises(TestException1) do
      retry_on_failure(TestException1) do
        puts "hello"
        raise TestException1.new
      end
    end
  end

  should "retry by given count for specified exceptions" do
    expects(:puts).with("hello").times(6)
    assert_raises(TestException1) do
      retry_on_failure(TestException1, TestException2, :retry_count => 5) do
        puts "hello"
        raise TestException1.new
      end
    end
  end

  should "not retry for unspecified exceptions" do
    expects(:puts).with("hello").once
    assert_raises(TestException1) do
      retry_on_failure(TestException2) do
        puts "hello"
        raise TestException1.new
      end
    end
  end

  should "sleep if retry_sleep given" do
    Subject.expects(:sleep).with(1)
    assert_raises(TestException1) do
      retry_on_failure(TestException1, :retry_count => 1, :retry_sleep => 1) do
        raise TestException1.new
      end
    end
  end

  should "not sleep if retry_sleep not given" do
    Subject.expects(:sleep).never
    assert_raises(TestException1) do
      retry_on_failure(TestException1, :retry_count => 1) do
        raise TestException1.new
      end
    end
  end

  should "wrap method with retry" do
    class WithRetry
      include ExceptionHelper::Retry

      def mymethod
        true
      end

      wrap_with_retry :mymethod
    end

    WithRetry.stubs(:mymethod_without_retry).raises(Exception).then.returns(true)

    # We should handle the exceptions. retry, and then move on without raising any further exceptions.
    WithRetry.new.mymethod
  end

  should "wrap method with retry with options" do
    class WithRetry
      include ExceptionHelper::Retry

      def mymethod
        true
      end

      wrap_with_retry :mymethod, :exceptions => [TestException1, TestException2], :retry_count => 9, :retry_sleep => 8
    end

    WithRetry.any_instance.expects(:retry_on_failure).with(TestException1, TestException2, {:retry_count => 9, :retry_sleep => 8})

    WithRetry.new.mymethod
  end

  should "not override logger on include" do
    class WithLogger
      def self.logger
        "Doesn't really do much"
      end

      include ExceptionHelper::Retry
    end

    assert_equal "Doesn't really do much", WithLogger.logger
  end
end
