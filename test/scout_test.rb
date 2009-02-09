require 'test_helper'
require File.join(File.dirname(__FILE__), 'test_helper')

class ScoutTest < ActiveSupport::TestCase
  
  def teardown
    Scout.reset!
    Scout::Reporter.reset!
  end
  
  # def start!
  #   self.reset!
  #   self.start_reporter!
  # end
  # 
  # # Ensures that the Reporter is started.
  # # 
  # def start_reporter!
  #   # ensure that the reporter runner thread is in the right PID
  #   if !Reporter.runner.nil? and Reporter.runner[:pid] != $$
  #     Reporter.runner.exit # be nice and terminate the thread first
  #     Reporter.runner = nil # remove runner so new reporter will get started
  #   end
  #   # start the reporting runner thread if not started yet
  #   Reporter.start! if Reporter.runner.nil?
  # end
  # 
  # def reset!
  #   reset_reports
  #   reset_queries
  # end
  # 
  # def reset_reports
  #   self.reports = nil # the 
  # end
  # 
  # def reset_queries
  #   self.queries = []
  # end
  
  def test_startup_resets_reports
    Scout.reports = {}
    assert_nothing_raised { Scout.start! }
    assert_equal nil, Scout.reports
  end
  
  def test_startup_starts_the_reporter_background_thread
    assert_equal nil, Scout::Reporter.runner
    assert_nothing_raised { Scout.start! }
    assert_equal Thread, Scout::Reporter.runner.class
    assert Scout::Reporter.runner.alive?
  end
  
  # def record_metrics(runtimes, params, response, options = {})
  #   self.reports ||= self.empty_report
  #   
  #   fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
  #   
  #   path = "#{params[:controller]}/#{params[:action]}"
  #   self.reports[:actions][path] ||= self.empty_action_report
  #   
  #   self.reports[:actions][path][:num_requests]   += 1
  #   self.reports[:actions][path][:runtime]        << runtimes[:total]
  #   self.reports[:actions][path][:db_runtime]     << self.queries.inject(0.0){ |total, (runtime, _)| total += runtime }
  #   self.reports[:actions][path][:render_runtime] << runtimes[:view]
  #   self.reports[:actions][path][:queries]        << self.queries
  # end
  
  def test_metrics_are_gathered_in_the_report_queue
    # assert false
  end
  
end
