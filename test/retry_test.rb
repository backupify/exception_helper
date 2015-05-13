require_relative 'test_helper'

class ExceptionHelperTest < TestCase
  include GemLogger::LoggerSupport
  include ExceptionHelper::Retry

  class TestException1 < StandardError; end
  class TestException2 < StandardError; end

  context "retry_on_failure" do
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
      Random.stubs(:rand).with(1000).returns(0)
      redefine_constant("DISABLE_EXCEPTION_RETRY_SLEEP", false) do
        self.class.expects(:sleep).with(1).once
        assert_raises(TestException1) do
          retry_on_failure(TestException1, :retry_count => 1, :retry_sleep => 1) do
            raise TestException1.new
          end
        end
      end
    end

    should "not sleep if retry_sleep not given" do
      self.class.expects(:sleep).never
      assert_raises(TestException1) do
        retry_on_failure(TestException1, :retry_count => 1) do
          raise TestException1.new
        end
      end
    end

    context 'exponential backoff retry' do
      should "have no impact on passing code" do
        expects(:puts).with("hello").once
        retry_on_failure(TestException1, :exponential_backoff => true) do
          puts "hello"
        end
      end

      should "retry for specified exceptions" do
        self.class.stubs(:sleep)
        expects(:puts).with("hello").at_least(2)
        assert_raises(TestException1) do
          retry_on_failure(TestException1, :exponential_backoff => true) do
            puts "hello"
            raise TestException1.new
          end
        end
      end

      should "not retry for unspecified exceptions" do
        expects(:puts).with("hello").once
        assert_raises(TestException1) do
          retry_on_failure(TestException2, :exponential_backoff => true) do
            puts "hello"
            raise TestException1.new
          end
        end
      end

      should "retry by given count for specified exceptions" do
        self.class.stubs(:sleep)
        expects(:puts).with("hello").times(6)
        assert_raises(TestException1) do
          retry_on_failure(TestException1, TestException2, :retry_count => 5, :exponential_backoff => true) do
            puts "hello"
            raise TestException1.new
          end
        end
      end

      should "sleep for random and increasing time" do
        Random.stubs(:rand).with(1000).returns(1).returns(2).returns(3).returns(4).returns(5)

        self.class.expects(:sleep).with(1.001)
        self.class.expects(:sleep).with(2.002)
        self.class.expects(:sleep).with(4.003)
        self.class.expects(:sleep).with(8.004)
        self.class.expects(:sleep).with(16.005)

        expects(:puts).with("hello").times(6)
        redefine_constant("DISABLE_EXCEPTION_RETRY_SLEEP", false) do
          assert_raises(TestException1) do
            retry_on_failure(TestException1, TestException2, :retry_count => 5, :exponential_backoff => true) do
              puts "hello"
              raise TestException1.new
            end
          end
        end
      end

      should "retry for subclasses of specified exceptions" do
        expects(:puts).with("hello").times(4)
        assert_raises(TestException1) do
          retry_on_failure(StandardError) do
            puts "hello"
            raise TestException1.new
          end
        end
      end
    end
  end

  context "retry_on_failure_except" do
    should "have no impact on passing code" do
      expects(:puts).with("hello").once
      retry_on_failure_except(TestException1) do
        puts "hello"
      end
    end

    should "retry for unspecified exceptions" do
      expects(:puts).with("hello").at_least(2)
      assert_raises(TestException2) do
        retry_on_failure_except(TestException1) do
          puts "hello"
          raise TestException2.new
        end
      end
    end

    should "not retry for specified exceptions" do
      expects(:puts).with("hello").once
      assert_raises(TestException2) do
        retry_on_failure_except(TestException2) do
          self.puts "hello"
          raise TestException2.new
        end
      end
    end

    should "not retry for subclasses of specified exceptions" do
      expects(:puts).with("hello").times(1)
      assert_raises(TestException1) do
        retry_on_failure_except(StandardError) do
          puts "hello"
          raise TestException1.new
        end
      end
    end
  end

  context "retry_on_failure_condition" do
    should "have no impact on passing code" do
      expects(:puts).with("hello").once
      retry_on_failure_condition(lambda {|e| true }) do
        puts "hello"
      end
    end

    should "retry when lambda returns true" do
      expects(:puts).with("hello").at_least(2)
      assert_raises(TestException1) do
        retry_on_failure_condition(lambda {|e| true}) do
          puts "hello"
          raise TestException1.new
        end
      end
    end

    should "not retry when lambda returns false" do
      expects(:puts).with("hello").once
      assert_raises(TestException1) do
        retry_on_failure_condition(lambda {|e| false}) do
          puts "hello"
          raise TestException1.new
        end
      end
    end
  end

  context "retry_block_on_failure" do
    should "log retries" do
      logger.expects(:warn).times(3)

      assert_raises(TestException1) do
        self.class.send(:retry_block_on_failure, {}, lambda {|e| true}) do
          raise TestException1.new
        end
      end
    end

    should "not log retries if option is false" do
      logger.expects(:warn).never

      assert_raises(TestException1) do
        self.class.send(:retry_block_on_failure, {:log_retries => false}, lambda {|e| true}) do
          raise TestException1.new
        end
      end
    end

    should "use default jitter when option is nil" do
      Random.expects(:rand).with(1000).returns(1000)
      redefine_constant("DISABLE_EXCEPTION_RETRY_SLEEP", false) do
        assert_raises(TestException1) do
          self.class.expects(:sleep).with(1.0).once
          self.class.send(:retry_block_on_failure, {:retry_count => 1, :retry_sleep => 0, :jitter => nil}, lambda {|e| true}) do
            raise TestException1.new
          end
        end
      end
    end

    should "use default jitter when option does not exist" do
      Random.expects(:rand).with(1000).returns(1000)
      redefine_constant("DISABLE_EXCEPTION_RETRY_SLEEP", false) do
        assert_raises(TestException1) do
          self.class.expects(:sleep).with(1.0).once
          self.class.send(:retry_block_on_failure, {:retry_count => 1, :retry_sleep => 0}, lambda {|e| true}) do
            raise TestException1.new
          end
        end
      end
    end

    should "override default jitter when option exists" do
      Random.expects(:rand).with(2000).returns(1500)
      redefine_constant("DISABLE_EXCEPTION_RETRY_SLEEP", false) do
        assert_raises(TestException1) do
          self.class.expects(:sleep).with(1.5).once
          self.class.send(:retry_block_on_failure, {:retry_count => 1, :retry_sleep => 0, :jitter => 2000}, lambda {|e| true}) do
            raise TestException1.new
          end
        end
      end
    end
  end
end
