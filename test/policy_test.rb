require "test_helper"
require "exception_helper/policy"

class ExceptionHelper::PolicyTest < ExceptionHelper::TestCase
  Subject = ExceptionHelper::Policy
  TestPolicy = Class.new(Subject)

  context Subject.name do
    subject { Subject }

    setup do
      # Clear out policies between tests
      Thread.current[Subject.send(:namespace)] = nil
    end

    context "::namespace" do
      should "return the class name" do
        assert_equal Subject.name, subject.send(:namespace)
      end
    end

    context "::policies" do
      should "return a consistent object" do
        first = subject.send(:policies)
        second = subject.send(:policies)
        assert_equal first.object_id, second.object_id
      end

      should "create main Thread policies if missing when creating Thread policies" do
        namespace = subject.send(:namespace)
        Thread.main[namespace] = nil
        assert_nil Thread.main[namespace]
        Thread.new { subject.send(:policies) }.join
        refute_nil Thread.main[namespace]
      end

      should "use a unique set of policies per Thread" do
        thread_policies = nil
        thread = Thread.new do
          thread_policies = subject.send(:policies)
        end
        thread.join
        main_policies = subject.send(:policies)
        refute_equal main_policies.object_id, thread_policies.object_id
        assert_equal main_policies.empty?, thread_policies.empty?
      end

      should "copy policies from Main thread" do
        assert_equal Thread.main, Thread.current
        policy_name = :test
        policy = subject.new(policy_name)
        subject.institute_policy(policy)
        assert_equal true, policy.in_effect?

        thread_policies = nil
        thread = Thread.new do
          thread_policies = subject.send(:policies)
          assert_equal policy, thread_policies[policy.name]
        end
        thread.join
        main_policies = subject.send(:policies)
        refute_equal main_policies.object_id, thread_policies.object_id
        assert_equal thread_policies[policy.name], main_policies[policy.name]

        other_policy = subject.new(:other)
        subject.institute_policy(other_policy)
        assert_nil thread_policies[other_policy.name]
        assert_equal main_policies[other_policy.name], other_policy
      end
    end

    context "::institute_policy" do
      setup do
        @policies = subject.send(:policies)
        @policy = subject.new(:test)
      end

      should "put the policy in effect and return true if a policy is not already in effect" do
        assert_equal true, subject.institute_policy(@policy)
        assert_equal true, subject.policy_in_effect?(@policy)
        assert_equal @policy, @policies[@policy.name]
      end

      should "only institute policy for current thread" do
        thread_policy_active = false
        maintain_thread = true

        thread = Thread.new do
          subject.institute_policy(@policy)
          assert_equal true, subject.policy_in_effect?(@policy)
          thread_policy_active = true
          while maintain_thread
            sleep 0.05
          end
        end
        while !thread_policy_active
          sleep 0.05
        end
        # Should not be in effect for primary thread
        assert_equal false, subject.policy_in_effect?(@policy)
        maintain_thread = false
        thread.join
      end

      should "return false if a policy is already in effect" do
        other_policy = subject.new(:test)
        assert_equal true, subject.institute_policy(other_policy)
        assert_equal false, subject.institute_policy(@policy)
        assert_equal false, subject.policy_in_effect?(@policy)
        refute_equal @policy, @policies[@policy.name]
      end
    end

    context "::policy_in_effect?" do
      setup do
        @policy = subject.new(:test)
      end

      should "return true if the given policy is in effect for the Thread" do
        thread = Thread.new do
          subject.institute_policy(@policy)
          assert_equal true, subject.policy_in_effect?(@policy)
        end
        thread.join
        # Should not be in effect for primary thread
        assert_equal false, subject.policy_in_effect?(@policy)
      end

      should "return false if the given policy is not in effect for the Thread" do
        thread_finished = false
        thread_policies_created = false
        thread = Thread.new do
          # Ensure policies for Thread created
          subject.send(:policies)
          thread_policies_created = true
          while Thread.main[subject.send(:namespace)][@policy.name].nil?
            sleep 0.05
          end
          # Should not be in effect for child thread
          assert_equal false, subject.policy_in_effect?(@policy)
          thread_finished = true
        end
        # Ensure child Thread policies have been forked before continuing
        while !thread_policies_created
          sleep 0.05
        end
        assert_equal true, subject.institute_policy(@policy)
        assert_equal true, subject.policy_in_effect?(@policy)
        thread.join
        assert_equal true, thread_finished
      end
    end

    context "::revoke_policy" do
      setup do
        @policy = subject.new(:test)
      end

      should "return false if the given policy is not in effect" do
        assert_equal true, subject.institute_policy(@policy)
        assert_equal true, subject.policy_in_effect?(@policy)
        assert_equal false, subject.revoke_policy(subject.new(@policy.name))
        assert_equal true, subject.policy_in_effect?(@policy)
      end

      should "revoke the policy and return true if the policy is in effect" do
        assert_equal true, subject.institute_policy(@policy)
        assert_equal true, subject.policy_in_effect?(@policy)
        assert_equal true, subject.revoke_policy(@policy)
        assert_nil subject.send(:policies)[@policy.name]
      end

      should "only revoke the policy for the current thread" do
        assert_equal true, subject.institute_policy(@policy)
        assert_equal true, subject.policy_in_effect?(@policy)

        thread = Thread.new do
          subject.revoke_policy(@policy)
          assert_equal false, subject.policy_in_effect?(@policy)
        end
        thread.join
        # Should not have revoked policy for primary thread
        assert_equal true, subject.policy_in_effect?(@policy)
      end
    end

    context "instance" do
      subject { Subject.new(@name) }

      setup do
        @name = :my_policy
      end

      context "#name" do
        should "return the policy name" do
          assert_equal @name, subject.name
        end
      end

      context "#in_effect?" do
        should "delegate to ::policy_in_effect?" do
          Subject.expects(:policy_in_effect?).with(subject)
          subject.in_effect?
        end
      end

      context "#institute" do
        should "delegate to ::institute_policy" do
          Subject.expects(:institute_policy).with(subject)
          subject.institute
        end
      end

      context "#revoke" do
        should "delegate to ::revoke_policy" do
          Subject.expects(:revoke_policy).with(subject)
          subject.revoke
        end
      end
    end

    context "subclass" do
      subject { TestPolicy }

      should "have mutex distinct from primary class" do
        mutex = subject.send(:mutex)
        assert_kind_of Mutex, mutex
        refute_equal Subject.send(:mutex), mutex
      end

      should "have policies distinct from primary class" do
        refute_equal Subject.send(:policies).object_id, subject.send(:policies).object_id
      end
    end
  end
end
