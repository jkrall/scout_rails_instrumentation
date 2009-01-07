$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

class Scout
  
  cattr_accessor :reports
  
  class << self
    
    def reset_reports
      self.reports = nil
    end
    
    def report(runtimes, params, response, options = {})
      self.reports ||= {}
      
      fix_runtimes_to_ms!(runtimes) if options[:in_seconds]
      
      path = "#{params[:controller]}/#{params[:action]}"
      self.reports[path] ||= {
        :num_requests => 0,
        :runtimes => [],
        :db_runtimes => [],
        :render_runtimes => []
      }
      
      self.reports[path][:num_requests]     += 1
      self.reports[path][:runtimes]         << runtimes[:total]
      self.reports[path][:db_runtimes]      << runtimes[:db]
      self.reports[path][:render_runtimes]  << runtimes[:view]
      
      puts
      puts "Path: %s" % path
      puts "Requests for path: %i" % self.reports[path][:num_requests]
      puts "Total runtime: %.2f" % runtimes[:total]
      puts "Runtimes: %s" % runtimes.inspect
      puts
      [:runtimes, :db_runtimes, :render_runtimes].each do |runtime|
        puts "Shortest #{runtime}: %.2f" % self.reports[path][runtime].min
        puts "Longest #{runtime}: %.2f"  % self.reports[path][runtime].max
        puts "Average #{runtime}: %.2f"  % (self.reports[path][runtime].sum / self.reports[path][:num_requests].to_f)
        puts
      end
    end
    
    # Fix times in seconds to time in milliseconds.
    # 
    def fix_runtimes_to_ms!(runtimes)
      runtimes[:db] *= 1000
      runtimes[:view] *= 1000
      runtimes[:total] *= 1000
    end
    
  end
  
end
