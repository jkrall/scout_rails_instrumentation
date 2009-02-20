$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'scout/reporter' # Scout::Reporter

class Scout
  
  RUNTIMES = [:runtime, :db_runtime, :render_runtime]
  
  cattr_accessor :reports, :queries, :reporter, :logger, :config
  
  class << self
    
    # returns true if configuration was successfully loaded, false if not
    def start!
      self.reset!
      if self.load_configuration
        self.start_reporter!
        return true
      end
      return false
    end
    
    # Load configuration from yaml. Only loads once in the beginning.
    # sets self.plugin_id, and returns true if successful
    def load_configuration
      self.config={
        :plugin_id=>nil,              # must be set by user in configuration, and must match the plugin id assigned by scoutapp.com
        :explain_queries_over=>100,   # queries taking longer than this (in milliseconds) will be EXPLAINed
        :interval=>30                 # frequency of execution of the background thread, in seconds
      }
      config_path=File.join(File.dirname(__FILE__),"../scout_config.yml")  
    
      return false if !File.exists(config_path)
      begin
        o=YAML.load(File.read(config_path))
        self.config[:interval]=o['interval'] if o['interval'].is_a?(Integer)
        self.config[:explain_queries_over]=o['explain_queries_over'] if o['explain_queries_over'].is_a?(Integer)
        
        # this can be a simple value, or a hash of hostnames=>values
        temp=o[RAILS_ENV]
        
        if temp.is_a?(Integer)
          self.config[:plugin_id]=temp
          puts "** Scout Instrumentation Loaded with plugin_id=#{self.plugin_id} for environment=#{RAILS_ENV}"
          return true
        elsif temp.is_a?(Hash)
          hostname=`hostname`
          temp2=temp[hostname]
          if temp.is_a?(Integer)
            self.plugin_id=temp2
            puts "** Scout Instrumentation Loaded with plugin_id=#{self.plugin_id} for environment=#{RAILS_ENV} and hostname=#{hostname}"
            return true
          else
            puts "** Could not load Scout Instrumentation for environment=#{RAILS_ENV} and hostname=#{hostname}"
          end
        else  
          puts "** Could not load Scout Instrumentation for environment=#{RAILS_ENV}"
        end
        return false # if we got to here, there was no successful config file loading
      rescue 
        puts "** Could not load Scout Instrumentation for environment=#{RAILS_ENV} : #{$!}"
        return false
      end
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
      self.reports = nil
    end
    
    def reset_queries
      self.queries = []
    end
    
    def record_metrics(runtimes, params, response, options = {})
      self.reports ||= self.empty_report
      
      fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
      
      path = "#{params[:controller]}/#{params[:action]}"
      self.reports[:actions][path] ||= self.empty_action_report
      
      self.reports[:actions][path][:num_requests]   += 1
      self.reports[:actions][path][:runtime]        << runtimes[:total]
      self.reports[:actions][path][:db_runtime]     << self.queries.inject(0.0){ |total, (runtime, _)| total += runtime }
      self.reports[:actions][path][:render_runtime] << runtimes[:view]
      self.reports[:actions][path][:queries]        << self.queries
    end
    
    def empty_report
      {
        :actions => {}
      }
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
                    logger.formatter = proc{|s,t,p,m|"%5s [%s] %s\n" % [s, t.strftime("%Y-%m-%d %H:%M:%S"), m]}
                    logger
                  end
    end
    
  end # << self
  
end
