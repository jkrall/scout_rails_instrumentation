$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'scout/reporter' # Scout::Reporter

class Scout
  
  RUNTIMES = [:runtime, :db_runtime, :render_runtime]
  
  cattr_accessor :reports, :queries, :reporter, :logger
  
  class << self
    
    def start!
      self.reset!
      self.start_reporter!
    end
    
    # Ensures that the Reporter is started.
    # 
    def start_reporter!
      # ensure that the reporter runner thread is in the right PID
      if !Reporter.runner.nil? and Reporter.runner[:pid] != $$
        Reporter.runner.exit # be nice and terminate the thread first
        Reporter.runner = nil # remove runner so new reporter will get started
      end
      # start the reporting runner thread if not started yet
      Reporter.start! if Reporter.runner.nil?
    end
    
    def reset!
      reset_reports
      reset_queries
    end
    
    def reset_reports
      self.reports = nil # the 
    end
    
    def reset_queries
      self.queries = []
    end
    
    def record_metrics(runtimes, params, response, options = {})
      self.reports ||= { :actions => {} }
      
      fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
      
      path = "#{params[:controller]}/#{params[:action]}"
      self.reports[:actions][path] ||= self.empty_action_report
      
      self.reports[:actions][path][:num_requests]   += 1
      self.reports[:actions][path][:runtime]        << runtimes[:total]
      self.reports[:actions][path][:db_runtime]     << self.queries.inject(0.0){ |total, (runtime, _)| total += runtime }
      self.reports[:actions][path][:render_runtime] << runtimes[:view]
      self.reports[:actions][path][:queries]        << self.queries
    end
    
    def empty_action_report
      {
        :num_requests     => 0,
        :runtime          => [],
        :db_runtime       => [],
        :render_runtime   => [],
        :queries          => []
      }
    end
    
    ### Utils
    
    # Fixes the runtimes to be in milliseconds.
    # 
    def fix_runtimes_to_ms!(runtimes)
      [:view, :total].each do |key|
        runtimes[key] = seconds_to_ms(runtimes[key])
      end
    end
    
    # Fix times in seconds to time in milliseconds.
    # 
    def seconds_to_ms(n)
      n * 1000.0
    end
    
    ### Resources
    
    def logger
      @logger ||= begin
                    logger = Logger.new(File.join(RAILS_ROOT, "log", "scout_instrumentation.log"))
                    logger.level = ActiveRecord::Base.logger.level
                    logger
                  end
    end
    
  end # << self
  
end
