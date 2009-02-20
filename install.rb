# This file is executed when the plugin is installed. It sets up the configuration file 
# and provides brief instructions for 

# template  
template_path=File.join(File.dirname(__FILE__), 'assets/scout_config_template')
path=File.expand_path(File.join(File.dirname(__FILE__), 'scout_config.yml'))

if File.exists?(path)
  puts "You already have a configuration file at #{path}. We've left it as-is. This is normal if you've re-installed the plugin. However, please check #{template_path} to see if anything has changed since your config file was created."
else
  File.open(path, "w") do |f|
    f.puts IO.read(template_path)
    puts <<-EOS 
** Welcome to Scout Rails instrumentation! **    

1. You need to have an account at http://scoutapp.com to use this plugin 
   (if you don't have an account yet, you can leave this plugin in place; it won't hurt anything)
2. You need to set your Rails Instrumentation plugin id in the configuration file: #{path}.
   Get your Rails Instrumentation plugin id from your account at http://scoutapp.com
    EOS
  end  
end
