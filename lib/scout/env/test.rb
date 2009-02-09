$scout_reporter = {}

class Scout
  class Reporter
    class << self
      
      def run_with_test_hooks
        $scout_reporter[:last_run] = Time.now
        $scout_reporter[:last_result] = run_without_test_hooks
      end
      alias_method_chain :run, :test_hooks
      
    end
  end
end
