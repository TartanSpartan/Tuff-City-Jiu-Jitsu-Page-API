require 'rails_helper'

RSpec.describe "Api::V1::Sessions", type: :request do
  Rails.application.reload_routes!

  def response_json
    JSON.parse(response.body)
  end

  describe "POST /api/v1/session" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "logs the user in and returns user details" do
        post "/api/v1/session", params: { email: "test@example.com", password: "password123" }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["email"]).to eq(user.email)
      end
    end

    context "with invalid credentials" do
      it "returns an unauthorized status" do
        post "/api/v1/session", params: { email: "test@example.com", password: "wrong_password" }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response_json["error"]).to eq("Invalid email or password")
      end
    end

    context "with non-existent email" do
      it "returns a not found status" do
        post "/api/v1/session", params: { email: "nonexistent@example.com", password: "any_password" }, as: :json

        expect(response).to have_http_status(:not_found)
        expect(response_json["error"]).to eq("Email not found")
      end
    end

  context "with valid credentials but different email casing" do
    it "logs the user in and returns user details" do
      post "/api/v1/session", params: { email: "Test@example.com", password: "password123" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response_json["user"]["email"]).to eq("test@example.com")
    end
  end

  context "with leading/trailing whitespace in email" do
    it "attempts login with trimmed email" do
      post "/api/v1/session", params: { email: " test@example.com ", password: "password123" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response_json["user"]["email"]).to eq("test@example.com")
    end
  end

  context "with leading/trailing whitespace in password" do
    it "attempts login with trimmed password" do
      post "/api/v1/session", params: { email: "test@example.com", password: " password123 " }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response_json["user"]["email"]).to eq(user.email)
    end
  end

  context "with valid credentials" do
    it "logs the user in and returns all expected user details" do
      post "/api/v1/session", params: { email: "test@example.com", password: "password123" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response_json["user"]["id"]).to eq(user.id)
      expect(response_json["user"]["email"]).to eq(user.email)
      expect(response_json["user"]["first_name"]).to eq(user.first_name)
      expect(response_json["user"]["last_name"]).to eq(user.last_name)
    end
  end

  it "logs the user in and returns the correct status and logged_in flag" do
    post "/api/v1/session", params: { email: "test@example.com", password: "password123" }, as: :json
  
    expect(response).to have_http_status(:ok)
    expect(response_json["status"]).to eq(200)
    expect(response_json["logged_in"]).to be_truthy
    expect(response_json["user"]["email"]).to eq(user.email)
  end

  context "with no password provided" do
    it "returns an unauthorized status or specific error" do
      post "/api/v1/session", params: { email: "test@example.com" }, as: :json
  
      expect(response).to have_http_status(:unauthorized) # Or your expected status
      expect(response_json["error"]).to be_present # Or your specific error message
    end
  end

  context "with no email provided" do
    it "returns an unauthorized status or specific error" do
      post "/api/v1/session", params: { password: "password123" }, as: :json
  
      expect(response).to have_http_status(:unauthorized) # Or your expected status
      expect(response_json["error"]).to be_present # Or your specific error message
    end
  end
end

  describe "DELETE /api/v1/session" do
    let!(:user) { create(:user) }

    before do
      # Simulate user being logged in and setting a potential Authorization header (though the current destroy action relies on session).
      post "/api/v1/session", params: { email: user.email, password: user.password }, as: :json
      @token = response.headers['Authorization']
      puts "Test Environment Request Host: #{request.host}"
    end

    it 'logs the user out by resetting the session and the session cookie' do
      # Expect no response body (head :no_content)
      delete "/api/v1/session", headers: { 'Authorization': @token }
    
      expect(response).to have_http_status(:no_content)
    
      set_cookie_header = response.headers['Set-Cookie']
      expect(set_cookie_header).to be_an(Array)
      expect(set_cookie_header).to include(
        a_string_including('_tuff_city_jiu_jitsu_api_tablet_session=; domain=www.example.com; path=/; max-age=0')
      )
    end

    context "when not logged in" do
      # When no user is logged in, the destroy action returns a 401 Unauthorized response.
      before do
        allow_any_instance_of(Api::V1::SessionsController).to receive(:current_api_v1_user).and_return(nil) # Mock current_user
      end

      it "returns an unauthorized status and error message" do
        delete "/api/v1/session" # No prior login
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8') # Check content type
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No active session found.') 
      end
    end

    context "with an invalid token" do
      # Note: The current destroy action does not explicitly authenticate using the Authorization header.
      # When no user is logged in (regardless of token), the action returns a 401 Unauthorized response.

      before do
        allow_any_instance_of(Api::V1::SessionsController).to receive(:current_api_v1_user).and_return(nil) # Mock current_user
      end

      it "returns an unauthorized status and error message as no user is logged in" do
        delete "/api/v1/session", headers: { 'Authorization': 'invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8') # Check content type
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No active session found.')
      end
    end
  end
end