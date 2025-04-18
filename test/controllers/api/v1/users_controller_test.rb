require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get current" do
    get api_v1_users_current_url
    assert_response :success
  end

  test "should get index" do
    get api_v1_users_index_url
    assert_response :success
  end

  test "should get create" do
    get api_v1_users_create_url
    assert_response :success
  end

  test "should get update" do
    get api_v1_users_update_url
    assert_response :success
  end

  test "should get email_available" do
    get api_v1_users_email_available_url
    assert_response :success
  end
end
