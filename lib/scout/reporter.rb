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
        $message_queues[name].enq object.to_json
      end
      def self.pop(name)
        $message_queues[name].deq
      end
    end
  end
end

class Scout
  class Reporter
    
    cattr_accessor :runner, :interval
    
    INTERVAL = 30.seconds # every
    LOCK = Mutex.new
    
    # This needs to be modified. It won't be used when the agent
    # is turned into a gem.
    API_PATH = '/Users/itsderek23/Projects/scout_agent/lib/scout_agent/api.rb'
    require API_PATH
    # TODO - Should be stored in a config file
    MISSION_ID = 32911
    
    class << self
      
      def reset!
        self.runner.exit rescue nil
        self.runner = nil
      end
      
      def start!(interval = INTERVAL)
        self.interval = interval.to_i
        self.runner ||= begin
          Thread.new(self) do |reporter|
            Thread.current[:pid] = $$ # record where thread is running,
                                      # so we can remove runaways (Passenger)
            loop do
              sleep(self.interval)
              reporter.run
            end
          end
        end
        self.runner.run # start the report loop
      end
      
      def run
        begin
          self.report!
        rescue Exception => e
          raise unless self.handle_exception!(e)
        end
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
            runtimes = report[:actions][action].delete(runtime)
            runtimes = calculate_report_runtimes(runtimes, action[:num_requests])
            report[:actions][action]["#{runtime}_avg"] = runtimes[:avg]
            report[:actions][action]["#{runtime}_max"] = runtimes[:max]
          end
        end
        
        # enqueue the message for background processing
        begin
          if ScoutAgent::API.queue_for_mission(MISSION_ID, report).success?
            logger.debug "Report queued"
          else
            logger.error "Error queuing report"
          end
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
    
    # This is a mocking method so that we can put an instance of a Reporter in
    # place of a real Thread for testing purposes.
    # 
    def run
      self.class.run
    end
    
  end
end
