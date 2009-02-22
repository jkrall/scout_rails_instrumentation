$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'scout/reporter' # Scout::Reporter

class Scout
  
  RUNTIMES = [:runtime, :db_runtime, :render_runtime]
  
  cattr_accessor :reports, :queries, :reporter, :logger, :config
  
  class << self
    
    def start!(&initializer)
      self.reset!
      if self.load_configuration
        self.start_reporter!
        yield
      end
    end
    
    # Load configuration from yaml. Only loads once in the beginning.
    # sets self.plugin_id, and returns true if successful
    def load_configuration
      self.config = {
        :plugin_id => nil,              # must be set by user in configuration, and must match the plugin id assigned by scoutapp.com
        :explain_queries_over => 100,   # queries taking longer than this (in milliseconds) will be EXPLAINed
        :interval => 30                 # frequency of execution of the background thread, in seconds
      }
      config_path = File.join(File.dirname(__FILE__), "..", "scout_config.yml")
      
      unless File.exists?(config_path)
        puts "** [ERROR] Could not load Scout Instrumentation."
        puts "   Check for config file at #{config_path}."
        raise LoadError.new("Could not load configuration file #{config_path}")
      end
      
      begin
        config = YAML.load(File.read(config_path))
        hostname = `hostname`.chomp
        
        self.config[:interval]              = config['interval']              if config['interval'].is_a?(Integer)
        self.config[:explain_queries_over]  = config['explain_queries_over']  if config['explain_queries_over'].is_a?(Integer)
        
        case id_or_hosts = config[RAILS_ENV] # load the plugin for the current environment
        when Integer
          self.config[:plugin_id] = id_or_hosts
        when Hash
          self.config[:plugin_id] = id_or_hosts[hostname]
          raise LoadError.new("No valid Plugin ID given.") unless self.config[:plugin_id].is_a?(Integer)
        when NilClass, FalseClass
          return false # do not load the instrumentation
        else
          raise LoadError.new("Invalid configuration! Expected one or more plugin IDs but got #{id_or_hosts.inspect}")
        end
        
        puts "** Scout Instrumentation Loaded with Plugin ID ##{self.config[:plugin_id]} for #{RAILS_ENV} on #{hostname}"
        return true # successfully loaded configuration
      rescue LoadError => exception
        puts "** [ERROR] Could not load Scout Instrumentation for #{RAILS_ENV} on #{hostname}"
        puts "   Error: %s" % exception.message
        raise
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
