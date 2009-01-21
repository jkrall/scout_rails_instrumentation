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
    
    # Obfuscates SQL queries, removing literal values.
    # 
    # This has several positive side-effects:
    # * information security (sensitive data removed)
    # * recognize emerging patterns (similar queries become identical)
    # * minimize payload size (for plugin delivery)
    # 
    # Examples:
    # 
    #   obfuscate_sql("SELECT * FROM actors WHERE id = 10;")
    #   # becomes "SELECT * FROM actors WHERE id = ?;"
    #   
    #   obfuscate_sql("SELECT * FROM actors WHERE name LIKE '%jones%';")
    #   # becomes "SELECT * FROM actors WHERE name LIKE ?;"
    #   
    #   obfuscate_sql("SELECT * FROM actors WHERE secret = 'bee''s nees';")
    #   # becomes "SELECT * FROM actors WHERE secret = ?;"
    # 
    def obfuscate_sql(sql)
      # remove escaped strings (to not falsely terminate next pattern)
      sql.gsub!(/(''|\\')/, "?")
      # remove literal string values
      sql.gsub!(/'[^']*'/, "?")
      # remove literal numerical values
      sql.gsub!(/\b\d+\b/, "?")
      sql
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
