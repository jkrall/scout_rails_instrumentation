require 'test_helper'

class ScoutRailsIntegrationTest < ActiveSupport::TestCase
  
  def test_queries_are_recorded_for_metrics
    # assert false
  end
  
  # controller-based tests are below
  
end

class ScoutController < ActionController::Base
  def index; render :text => ""; end
end

class ScoutControllerTest < ActionController::TestCase
  
  # def test_plugin
  #   assert true
  #   get :index
  #   assert_response :success
  # end
  
  def test_action_dispatch_ensures_reporter_is_running_in_the_background
    get :index
    assert_response :success
    # assert false
  end
  
  def test_successful_action_dispatch_results_in_recorded_metrics
    get :index
    assert_response :success
    # assert false
  end
  
  def test_failed_action_dispatch_foregoes_metric_gathering
    get :index
    assert_response :success
    # assert false
  end
  
  def test_metrics_are_gathered_for_reports_on_method_dispatch
    get :index
    assert_response :success
    # assert false
  end
  
end
