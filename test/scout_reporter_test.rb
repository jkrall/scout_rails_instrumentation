require 'test_helper'
require File.join(File.dirname(__FILE__), 'test_helper')

class ScoutReporterTest < ActiveSupport::TestCase
  include ScoutTestHelpers
  
  def setup
    Scout::Reporter.runner = Scout::Reporter.new
  end
  
  def test_reporter_runs_at_regular_intervals
    # assert false
  end
  
  def test_start_sets_up_runner_and_initiates_run_cycle
    # assert false
  end
  
  def test_reports_reset_collected_statistics_for_new_iteration
    Scout::Reporter.runner = Scout::Reporter.new
    Scout.record_metrics(*mocked_request)
    assert_nothing_raised { Scout::Reporter.runner.run }
    assert_equal nil, Scout.reports
  end
  
  def test_reporter_handles_common_exceptions_gracefully
    ScoutAgent::API.expects(:queue_message).raises(Timeout::Error, 'testing failures')
    assert_nothing_raised { Scout::Reporter.runner.run }
  end
  
  def test_reporter_can_calculate_report_times_given_range_of_actual_times
    # calculate_report_runtimes
    # assert false
  end
  
end
