require 'scout/rails'
ActionController::Base.class_eval do
  alias_method_chain :perform_action, :instrumentation
end
puts "** Scout Instrumentation Loaded"
