require 'test/unit'
require 'rubygems'
require 'shoulda'

### Load Rails

plugin_root = File.join(File.dirname(__FILE__), '..')
version = ENV['RAILS_VERSION']
version = nil if version and version == ""

# first look for a symlink to a copy of the framework
if !version and framework_root = ["#{plugin_root}/rails", "#{plugin_root}/../../rails"].find { |p| File.directory? p }
  puts "found framework root: #{framework_root}"
  # this allows for a plugin to be tested outside of an app and without Rails gems
  $:.unshift "#{framework_root}/activesupport/lib", "#{framework_root}/activerecord/lib", "#{framework_root}/actionpack/lib"
else
  # simply use installed gems if available
  puts "using Rails#{version ? ' ' + version : nil} gems"
  
  if version
    gem 'rails', version
  else
    gem 'actionpack'
    gem 'activerecord'
  end
end

require 'actionpack'
require 'action_controller'
require 'active_record'

RAILS_GEM_VERSION = ActionPack::VERSION::STRING

### Inject behavior into Rails (same as init.rb)

require 'scout/rails'
ActionController::Base.class_eval do
  alias_method_chain :perform_action, :instrumentation
end
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  alias_method_chain :log, :instrumentation
end
