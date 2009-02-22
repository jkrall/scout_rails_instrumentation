begin
  # TODO: Fix this issue with the load agent path.
  $:.unshift('/Users/itsderek23/Projects/scout_agent/lib/')
  $:.unshift('/Users/mtodd/Projects/Highgroove/Scout/scout_agent/lib/')
  $:.unshift('/Users/andre/projects/rails/scout_agent/lib/')
  $:.unshift('/root/scout_agent/lib/')  
  require 'scout_agent/api' # ScoutAgent::API
rescue LoadError
  raise "Unable load the ScoutAgent::API"
end

class Scout
  # Reporter relies on two configuration settings:
  # * config[:plugin_id]: the plugin id provided in the users' account at
  #                       scoutapp.com. User provides this the config file.
  # * config[:interval]: the interval at which the instrumentation runs in
  #                      seconds. 30 is the default.
  #                      It is unusual for the user to need to change this.
  # 
  # Optional configuration options include:
  # * config[:explain_queries_over]: run EXPLAINs for any queries that take
  #                                  longer than this (in milliseconds).
  # 
  class Reporter
    cattr_accessor :runner, :interval
    LOCK = Mutex.new
    
    class << self
      
      def reset!
        self.runner.exit rescue nil
        self.runner = nil
      end
      
      def start!(interval = Scout.config[:interval].seconds)
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
        calculate_report_runtimes!(report)
        
        # calculate average request time and throughput
        report[:avg_request_time], report[:throughput] = calculate_avg_request_time_and_throughput(report)
        
        run_explains_for_slow_queries!(report)
        
        # enqueue the message for background processing
        begin
          response = ScoutAgent::API.queue_for_mission(Scout.config[:plugin_id], report)
          if response.success?
            logger.debug "Report queued"
          else
            logger.error "Error:  #{response.error_message} (#{response.error_code})"
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
      
      def calculate_report_runtimes!(report)
        report[:actions].each do |(path, action)|
          RUNTIMES.each do |runtime|
            runtimes = report[:actions][path].delete(runtime)
            avg, max = calculate_avg_and_max_runtimes(runtimes, action[:num_requests])
            report[:actions][path]["#{runtime}_avg".to_sym] = avg
            report[:actions][path]["#{runtime}_max".to_sym] = max
          end
        end
      end
      
      def calculate_avg_and_max_runtimes(runtimes, num_requests)
        [(runtimes.sum / num_requests.to_f), runtimes.max]
      end
      
      def calculate_avg_request_time_and_throughput(report)
        avg_request_time = report[:actions].map{|(p,a)| a[:runtime_avg] }.sum / report[:actions].size
        throughput = (60.0 * 1000) / avg_request_time # adjusts for ms
        [avg_request_time, throughput]
      end
      
      def run_explains_for_slow_queries!(report)
        report[:actions].each do |(path, action)|
          action[:queries].each_with_index do |queries, i|
            queries.each_with_index do |(ms, sql), j|
              if sql =~ /^SELECT /i and ms > Scout.config[:explain_queries_over]
                report[:actions][path][:queries][i][j] << ActiveRecord::Base.connection.explain(sql)
                # TODO: determine a better place for the snapshot
                ScoutAgent::API.take_snapshot(:background => true)
              end
            end
          end
        end
      rescue Exception => e
        logger.error "An error occurred EXPLAINing a query: %s" % e.message
        # logger.error "\t%s" % e.backtrace.join("\n\t") # unneeded
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
