require 'pp'

class Scout
  class Reporter
    
    cattr_accessor :runner
    
    INTERVAL = 30.seconds # every
    LOCK = Mutex.new
    
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
        return if Scout.reports.nil? or Scout.reports.empty? # no report is necessary
        
        timestamp = Time.now.strftime("%Y-%m-%d %H:%I:%S (%s)")
        report = nil
        
        # atomically pull out the report then reset
        LOCK.synchronize do
          # essentially we're blocking the reports from being modified until
          # after we've secured the contents of the report.
          report = Scout.reports.dup
          Scout.reset! # reset the accumulated reports
        end
        
        ### refactor below into separate Thread
        
        # calculate report runtimes
        report.each do |(path, action)|
          next if path==:snapshots # temporary        
          RUNTIMES.each do |runtime|
            action[runtime] = calculate_report_runtimes(action[runtime], action[:num_requests])
          end
        end

        report[:time]=DateTime.now
        
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
