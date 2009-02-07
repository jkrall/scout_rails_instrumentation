require 'rubygems'
require 'active_support'
require 'active_support/test_case'

# The X-Runtime Fix and the Benchmark Fix require this constant usually set
# by config/environment.rb
RAILS_GEM_VERSION = ActionPack::VERSION::STRING

### Inject behavior into Rails (same as init.rb)

require 'scout/rails'
Scout.start!
ActionController::Base.class_eval do
  alias_method_chain :perform_action, :instrumentation
end
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  alias_method_chain :log, :instrumentation
end
