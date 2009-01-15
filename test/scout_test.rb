require 'test_helper'

class ScoutTest < Test::Unit::TestCase
  
  should "collect metrics for requests" do
    Scout.reports
  end
  
end
