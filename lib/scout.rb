$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

# require 'thread'
require 'pp'

class Scout
  
  RUNTIMES = [:runtime, :db_runtime, :render_runtime]
  
  cattr_accessor :reports, :queries,
    :lock, :reporter,
    :logger,
    :report_interval, :last_report
  
  class << self
    
    # Returns how often reports should be sent.
    # 
    def report_interval
      @report_interval ||= 30.seconds # every
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
      
      if ((self.last_report || 30.seconds.ago) + self.report_interval) <= Time.now
        self.report!
      end
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
    
    def report!
      return if self.reports.empty? # no report is necessary
      
      timestamp = Time.now.strftime("%Y-%m-%d %H:%I:%S (%s)")
      report = nil
      
      # atomically pull out the report then reset
      self.lock.synchronize do
        # essentially we're blocking the reports from being modified until
        # after we've secured the contents of the report.
        report = self.reports.dup
        reset! # reset the accumulated reports
      end
      
      ### refactor below into separate Thread
      
      # calculate report runtimes
      report.each do |(path, action)|
        RUNTIMES.each do |runtime|
          action[runtime] = calculate_report_runtimes(action[runtime], action[:num_requests])
        end
      end
      
      # enqueue the message for background processing
      begin
        filename = timestamp.gsub(/[^\d]+/, '') # strip out all non-digits
        FileUtils.mkdir_p(File.join(RAILS_ROOT, 'tmp', 'scout-mq'))
        File.open(File.join(RAILS_ROOT, 'tmp', 'scout-mq', filename), "w") do |file|
          file << Marshal.dump(report)
        end
      end
      
      # log the report
      begin
        logger.info "=== Reporting [%s]" % timestamp
        logger.info "="*80
        
        report.each do |(path, action)|
          logger.info "  "
          logger.info "* Path: %s" % path
          logger.info "  Requests: %i" % action[:num_requests]
          logger.info "  "
          
          logger.info "   Runtimes:"
          RUNTIMES.each do |runtime|
            # self.logger.info "Shortest #{runtime}: %.2fms" % self.reports[path][runtime].min
            logger.info "   * Average #{runtime}: %.2fms"  % action[runtime][:avg]
            logger.info "   * Longest #{runtime}: %.2fms"  % action[runtime][:max]
          end
          logger.info "  "
          
          logger.info "  Queries:"
          action[:queries].each do |query|
            logger.info "   * [%.5fms] %s" % query # [ms, sql]
          end
        end
        
        logger.debug ""
        logger.debug "Debug:"
        PP.pp(report, Scout.logger.instance_variable_get("@logdev").dev) if logger.debug? # hack!
        
        logger.info ""
        logger.info "="*80
        logger.info ""
      end
      
      # mark the report time so we know when to fire off the next report
      self.last_report = Time.now
    end
    
    ### Utils
    
    def calculate_report_runtimes(runtimes, num_requests)
      {
        :avg => (runtimes.sum / num_requests.to_f),
        :max => runtimes.max
      }
    end
    
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
    
    def lock
      @lock ||= Mutex.new
    end
    
  end # << self
  
end
