module ExceptionHelper
  class Policy
    attr_reader :name
    @mutex = Mutex.new

    def self.inherited(base)
      base.instance_variable_set(:@mutex, Mutex.new)
    end

    def self.ensure_per_thread_policies
      return unless Thread.current[namespace].nil?
      # Must synchronize here to ensure the main thread's policy registry is
      # created before a child thread's.
      mutex.synchronize do
        Thread.main[namespace] ||= {}
        if Thread.current != Thread.main
          Thread.current[namespace] = Thread.main[namespace].dup
        end
      end
      nil
    end
    private_class_method :ensure_per_thread_policies

    def self.policies
      ensure_per_thread_policies
      Thread.current[namespace]
    end
    private_class_method :policies

    def self.mutex
      @mutex
    end
    private_class_method :mutex

    def self.namespace
      self.name
    end
    private_class_method :namespace

    def self.institute_policy(policy)
      return false if policies.key?(policy.name)
      policies[policy.name] = policy
      true
    end

    def self.policy_in_effect?(policy)
      policies[policy.name] == policy
    end

    def self.revoke_policy(policy)
      return false unless policy_in_effect?(policy)
      policies.delete(policy.name)
      true
    end

    def initialize(name)
      @name = name
    end

    def in_effect?
      self.class.policy_in_effect?(self)
    end

    def institute
      self.class.institute_policy(self)
    end

    def revoke
      self.class.revoke_policy(self)
    end
  end
end
