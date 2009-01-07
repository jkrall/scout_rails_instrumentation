$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

class Scout
  
  cattr_accessor :reports
  
  class << self
    
    def reset_reports
      self.reports = nil
    end
    
    def report(runtimes, params, response)
      self.reports ||= {}
      
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
      puts "Runtimes: " + runtimes.inspect
      puts "Total runtime: " + response.headers["X-Runtime"]
      puts
      puts "Path: #{path}"
      puts "Requests for path: #{self.reports[path][:num_requests]}"
      puts
      puts self.reports.inspect
      puts
    end
    
  end
  
end
