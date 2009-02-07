require 'test_helper'

class ScoutTest < ActiveSupport::TestCase
  
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
  
  def test_startup
    # Scout.start!
    # Scout.reset!
    # assert false
  end
  
  def test_reports_reset_collected_statistics_for_new_iteration
    # Scout::Reporter.runner.run
    # assert false
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
