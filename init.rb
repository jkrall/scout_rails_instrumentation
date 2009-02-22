if RAILS_ENV == "production" || RAILS_ENV == "development"
  require 'scout/rails'
  # scout fails to start if it can't load its config file, or if
  # it doesn't have a plugin_id set in the config file.
  if Scout.start! 
    ActionController::Base.class_eval do
      alias_method_chain :perform_action, :instrumentation
    end
    ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
      alias_method_chain :log, :instrumentation
    end
  end
end
