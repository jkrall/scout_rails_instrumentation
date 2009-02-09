require 'mocha'

# The X-Runtime Fix and the Benchmark Fix require this constant usually set
# by config/environment.rb
(RAILS_GEM_VERSION = ActionPack::VERSION::STRING) rescue nil

### Inject behavior into Rails (same as init.rb)

# require 'scout/rails'
# # Scout.start!
# ActionController::Base.class_eval do
#   alias_method_chain :perform_action, :instrumentation
# end
# ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
#   alias_method_chain :log, :instrumentation
# end

### Mocking methods

module ScoutTestHelpers
  
  def mocked_request(runtimes = {}, params = {}, response = nil, options = {})
    runtimes = {:total => 5, :view => 2}.merge(runtimes)
    params = {:controller => "tests", :action => "index"}.merge(params)
    [runtimes, params, response, options]
  end
  
end
