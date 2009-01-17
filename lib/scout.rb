$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'scout/reporter' # Scout::Reporter

class Scout
  
  RUNTIMES = [:runtime, :db_runtime, :render_runtime]
  
  cattr_accessor :reports, :queries, :reporter, :logger
  
  class << self
    
    def start!
      self.reset!
      Reporter.start!
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
      self.reports ||= {}
      
      fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
      
      path = "#{params[:controller]}/#{params[:action]}"
      self.reports[path] ||= self.empty_action_report
      
      self.reports[path][:num_requests]     += 1
      self.reports[path][:runtime]          << runtimes[:total]
      self.reports[path][:db_runtime]       << runtimes[:db]
      self.reports[path][:render_runtime]   << runtimes[:view]
      self.queries.each { |query| self.reports[path][:queries] << query }
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
      [:db, :view, :total].each do |key|
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
