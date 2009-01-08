$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

class Scout
  
  cattr_accessor :reports
  cattr_accessor :queries
  
  class << self
    
    def reset_reports
      self.reports = nil
    end
    
    def report(runtimes, params, response, options = {})
      self.reports ||= {}
      
      fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
      
      path = "#{params[:controller]}/#{params[:action]}"
      self.reports[path] ||= {
        :num_requests     => 0,
        :runtimes         => [],
        :db_runtimes      => [],
        :render_runtimes  => [],
        :queries          => []
      }
      
      self.reports[path][:num_requests]     += 1
      self.reports[path][:runtimes]         << runtimes[:total]
      self.reports[path][:db_runtimes]      << runtimes[:db]
      self.reports[path][:render_runtimes]  << runtimes[:view]
      self.reports[path][:queries]          =  self.queries
      puts
      puts "Path: %s" % path
      puts "Requests for path: %i" % self.reports[path][:num_requests]
      puts "Total runtime: %.2fms" % runtimes[:total]
      puts "Runtimes: %s" % runtimes.inspect
      puts
      [:runtimes, :db_runtimes, :render_runtimes].each do |runtime|
        puts "Shortest #{runtime}: %.2fms" % self.reports[path][runtime].min
        puts "Longest #{runtime}: %.2fms"  % self.reports[path][runtime].max
        puts "Average #{runtime}: %.2fms"  % (self.reports[path][runtime].sum / self.reports[path][:num_requests].to_f)
        puts
      end
      self.queries.each do |(runtime, sql)|
        puts "(%.2fms) %s" % [runtime, sql]
      end
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
    
  end
  
end
