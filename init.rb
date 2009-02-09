if RAILS_ENV == "production"
  require 'scout/rails'
  Scout.start!
  ActionController::Base.class_eval do
    alias_method_chain :perform_action, :instrumentation
  end
  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    alias_method_chain :log, :instrumentation
  end
  puts "** Scout Instrumentation Loaded"
end
