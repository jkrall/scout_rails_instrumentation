require 'pp'

class Scout
  class Reporter
    
    cattr_accessor :runner
    
    INTERVAL = 30.seconds # every
    LOCK = Mutex.new
    
    # This needs to be modified. It won't be used when the agent
    # is turned into a gem.
    API_PATH = '/Users/itsderek23/Projects/scout_agent/lib/scout_agent/api.rb'
    require API_PATH
    # TODO - Should be stored in a config file
    MISSION_ID = 32911
    # If true, then messages aren't sent in the background and the response is checked. 
    DEBUG_MODE = true
    
    class << self
      
      def start!
        self.runner ||= begin
          Thread.new(self) do |reporter|
            Thread.current[:pid] = $$ # record where thread is running,
                                      # so we can remove runaways (Passenger)
            loop do
              begin
                sleep(INTERVAL.to_i)
                reporter.report!
              rescue Exception => e
                raise unless reporter.handle_exception!(e)
              end
            end
          end
        end
        self.runner.run # start the report loop
      end
      
      def report!
        return if Scout.reports.nil? or Scout.reports[:actions].empty? # no report is necessary
        
        report_time = Time.now.utc
        timestamp = report_time.strftime("%Y-%m-%d %H:%I:%S (%s)")
        report = nil
        
        # atomically pull out the report then reset
        LOCK.synchronize do
          # essentially we're blocking the reports from being modified until
          # after we've secured the contents of the report.
          report = Scout.reports.dup
          Scout.reset! # reset the accumulated reports
        end
        
        ### refactor below to report directly to the Scout agent
        
        report[:time] = report_time
        
        # calculate report runtimes
        report[:actions].each do |(path, action)|
          RUNTIMES.each do |runtime|
            action[runtime] = calculate_report_runtimes(action[runtime], action[:num_requests])
          end
        end
        
        # enqueue the message for background processing
        begin
          # filename = timestamp.gsub(/[^\d]+/, '') # strip out all non-digits
          #           filename = "#{filename}-#{$$}.dump"
          #           path = File.join(RAILS_ROOT, 'tmp', 'scout-mq')
          #           FileUtils.mkdir_p(path)
          #           File.open(File.join(path, filename), "w") do |file|
          #             file << Marshal.dump(report)
          #           end
          opts = DEBUG_MODE ? {} : {:background => true}
          response = ScoutAgent::API.queue_for_mission(MISSION_ID, report)
          if DEBUG_MODE
            if response.success?
              logger.info "[#{Time.now}] Queued report"
            else
              logger.info "[#{Time.now}] Error queuing report"
            end
          end
        end
        
        # log the report
        begin
          logger.info "=== Reporting [%s]" % timestamp
          logger.info "="*80
          
          report[:actions].each do |(path, action)|
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
            
            logger.info "   Queries:"
            action[:queries].each do |query_set|
              query_set.each do |query|
                logger.info "   * [%.5fms] %s" % query # [ms, sql]
              end
              logger.info "   = Total queries: %i\tTotal runtime: %.5fms" % [query_set.size, query_set.map{|(m,s)|m}.sum]
            end
          end
          
          logger.debug ""
          logger.debug "Debug:"
          PP.pp(report, Scout.logger.instance_variable_get("@logdev").dev) if logger.debug? # hack!
          
          logger.info ""
          logger.info "="*80
          logger.info ""
        end
      end
      
      def handle_exception!(e)
        case e
        when Timeout::Error
          logger.error e.message
        when Exception
          logger.error "An unexpected error occurred while reporting: #{e.message}"
          logger.error e.inspect
          logger.error "\t" + e.backtrace.join("\n\t")
        end
      end
      
      def calculate_report_runtimes(runtimes, num_requests)
        {
          :avg => (runtimes.sum / num_requests.to_f),
          :max => runtimes.max
        }
      end
      
      def logger(*args)
        Scout.logger(*args)
      end
      
    end
    
  end
end
