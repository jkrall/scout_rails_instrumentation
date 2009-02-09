require 'test_helper'
require File.join(File.dirname(__FILE__), 'test_helper')

class ScoutReporterTest < ActiveSupport::TestCase
  include ScoutTestHelpers
  
  def setup
    Scout::Reporter.runner = Scout::Reporter.new
  end
  
  def teardown
    Scout::Reporter.reset!
  end
  
  def test_reporter_runs_at_regular_intervals
    # assert false
  end
  
  def test_start_sets_up_runner_and_initiates_run_cycle
    Scout::Reporter.reset!
    assert_nothing_raised { Scout::Reporter.start! }
    assert Scout::Reporter.runner.is_a?(Thread)
    assert Scout::Reporter.runner.alive?
  end
  
  def test_reports_reset_collected_statistics_for_new_iteration
    Scout::Reporter.runner = Scout::Reporter.new
    Scout.record_metrics(*mocked_request)
    assert_nothing_raised { Scout::Reporter.runner.run }
    assert_nil Scout.reports
  end
  
  def test_reporter_handles_common_exceptions_gracefully
    ScoutAgent::API.expects(:queue_message).raises(Timeout::Error, 'testing failures')
    assert_nothing_raised { Scout::Reporter.runner.run }
  end
  
  def test_reporter_can_calculate_report_times_given_range_of_actual_times
    runtimes, requests = [12, 14, 81, 15, 22], 5
    report = Scout::Reporter.calculate_report_runtimes(runtimes, requests)
    assert_equal runtimes.max, report[:max]
    assert_equal runtimes.sum / requests.to_f, report[:avg]
  end
  
end
