require 'pp'
begin
  require 'scout_agent/api' # ScoutAgent::API
rescue LoadError
  STDERR.puts "** Loading ScoutAgent::API mock (for testing)"
  require 'json'
  $message_queues = Hash.new { |h,k| h[k] = Queue.new }
  class ScoutAgent
    class API
      def self.queue_message(name, object)
        $message_queues[name] = object.to_json
      end
    end
  end
end

class Scout
  class Reporter
    
    cattr_accessor :runner, :interval
    
    INTERVAL = 30.seconds # every
    LOCK = Mutex.new
    
    class << self
      
      def start!(interval = INTERVAL)
        self.interval = interval.to_i
        self.runner ||= begin
          Thread.new(self) do |reporter|
            Thread.current[:pid] = $$ # record where thread is running,
                                      # so we can remove runaways (Passenger)
            loop do
              begin
                sleep(self.interval)
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
        
        report[:time] = report_time
        
        # calculate report runtimes
        report[:actions].each do |(path, action)|
          RUNTIMES.each do |runtime|
            action[runtime] = calculate_report_runtimes(action[runtime], action[:num_requests])
          end
        end
        
        begin
          # enqueue the message for background processing
          ScoutAgent::API.queue_message("rails_instrumentation", report)
        end
      end
      alias run report!
      
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
