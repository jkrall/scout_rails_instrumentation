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
    Scout::Reporter.reset!
    assert_nothing_raised { Scout::Reporter.start!(0.1.seconds) }
    
    3.times do |n|
      sleep 0.2 # seconds
      assert_in_delta Time.now - 0.1.seconds.ago, Time.now - $scout_reporter[:last_run], 0.1.seconds
    end
  end
  
  def test_start_sets_up_runner_and_initiates_run_cycle
    Scout::Reporter.reset!
    assert_nothing_raised { Scout::Reporter.start!(0.1.seconds) }
    
    assert Scout::Reporter.runner.is_a?(Thread)
    assert Scout::Reporter.runner.alive?
    assert !$scout_reporter[:last_run].nil?
  end
  
  def test_reports_reset_collected_statistics_for_new_iteration
    Scout::Reporter.runner = Scout::Reporter.new
    Scout.record_metrics(*mocked_request)
    assert_nothing_raised { Scout::Reporter.runner.run }
    assert_nil Scout.reports
  end
  
  def test_reporter_handles_common_exceptions_gracefully
    Scout.record_metrics(*mocked_request)
    ScoutAgent::API.expects(:queue_for_mission).raises(Timeout::Error, 'testing failures')
    assert_nothing_raised { Scout::Reporter.runner.run }
  end
  
  def test_reporter_can_calculate_report_times_given_range_of_actual_times
    runtimes, requests = [12, 14, 81, 15, 22], 5
    avg, max = Scout::Reporter.calculate_report_runtimes(runtimes, requests)
    assert_equal runtimes.max, max
    assert_equal runtimes.sum / requests.to_f, avg
  end
  
end
