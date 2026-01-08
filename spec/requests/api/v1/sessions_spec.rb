require 'rails_helper'

RSpec.describe "Api::V1::Sessions", type: :request do
  Rails.application.reload_routes!

  def response_json
    JSON.parse(response.body)
  end

  # --- GET /api/v1/sessions/new ---
  describe "GET /new" do
    context "without an error param" do
      it "returns a successful response with a default message" do
        get new_api_v1_session_path, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_json['message']).to eq("Please sign in.")
      end
    end

    context "with an omniauth_failure error" do
      it "returns an unauthorized status with an error message" do
        get new_api_v1_session_path, params: { error: 'omniauth_failure', reason: 'User cancelled' }, as: :json
        expect(response).to have_http_status(:unauthorized)
        expect(response_json['error']).to eq("Omniauth Failure")
        expect(response_json['reason']).to eq("User cancelled")
      end
    end
  end

  # --- POST /api/v1/sessions ---
  describe "POST /api/v1/session" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    # NOTE: Updated params structure to reflect the `session_params` strong parameters definition
    # i.e., wrapping email/password in a `session` hash.

    context "with valid credentials" do
      it "logs the user in and returns user details" do
        post "/api/v1/session", params: { session: { email: "test@example.com", password: "password123" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["email"]).to eq(user.email)
      end
    end

    context "with invalid credentials" do
      it "returns an unauthorized status" do
        post "/api/v1/session", params: { session: { email: "test@example.com", password: "wrong_password" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response_json["error"]).to eq("Invalid email or password")
      end
    end

    context "with non-existent email" do
      it "returns an unauthorized status with a generic error" do
        post "/api/v1/session", params: { session: { email: "nonexistent@example.com", password: "any_password" } }, as: :json

        expect(response).to have_http_status(:unauthorized) # Changed from :not_found (404) to :unauthorized (401)
        expect(response_json["error"]).to eq("Invalid email or password") # Changed to generic error
      end
    end

    context "with valid credentials but different email casing" do
      it "logs the user in and returns user details" do
        post "/api/v1/session", params: { session: { email: "Test@example.com", password: "password123" } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["email"]).to eq("test@example.com")
      end
    end

    context "with leading/trailing whitespace in email" do
      it "attempts login with trimmed email" do
        post "/api/v1/session", params: { session: { email: " test@example.com ", password: "password123" } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["email"]).to eq("test@example.com")
      end
    end

    context "with leading/trailing whitespace in password" do
      it "attempts login with trimmed password" do
        post "/api/v1/session", params: { session: { email: "test@example.com", password: " password123 " } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["email"]).to eq(user.email)
      end
    end

    context "with valid credentials" do
      it "logs the user in and returns all expected user details" do
        post "/api/v1/session", params: { session: { email: "test@example.com", password: "password123" } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_json["user"]["id"]).to eq(user.id)
        expect(response_json["user"]["email"]).to eq(user.email)
        expect(response_json["user"]["first_name"]).to eq(user.first_name)
        expect(response_json["user"]["last_name"]).to eq(user.last_name)
      end
    end

    it "logs the user in and returns the correct status and logged_in flag" do
      post "/api/v1/session", params: { session: { email: "test@example.com", password: "password123" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response_json["status"]).to eq(200)
      expect(response_json["logged_in"]).to be_truthy
      expect(response_json["user"]["email"]).to eq(user.email)
    end

    context "with no password provided" do
      it "returns an unauthorized status or specific error" do
        post "/api/v1/session", params: { session: { email: "test@example.com" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response_json["error"]).to eq("Invalid email or password")
      end
    end

    context "with no email provided" do
      it "returns an unauthorized status or specific error" do
        post "/api/v1/session", params: { session: { password: "password123" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response_json["error"]).to eq("Invalid email or password")
      end
    end
  end

  # --- DELETE /api/v1/sessions ---
  describe "DELETE /api/v1/session" do
    let!(:user) { create(:user) }

    before do
      # Log in the user before each test to establish a session
      post "/api/v1/session", params: { session: { email: user.email, password: user.password } }, as: :json
      @token = response.headers['Authorization']
    end

    it 'logs the user out and destroys the session' do
      delete "/api/v1/session", headers: { 'Authorization': @token }
      expect(response).to have_http_status(:no_content)
    end

    # New, robust test to confirm the session is actually gone
    it 'prevents access to current user endpoint after successful logout' do
      # 1. Log out the user
      delete "/api/v1/session", headers: { 'Authorization': @token }

      # 2. Attempt to access a protected endpoint after logout (should fail)
      get "/api/v1/users/current"

      # Update the expectation to match the actual error message from the protected resource
      expect(response).to have_http_status(:unauthorized)
      expect(response_json['error']).to eq('User must be logged in to access this resource')
    end


    context "when not logged in" do
      before do
        # Mock current_api_v1_user to be nil for this context
        allow_any_instance_of(Api::V1::SessionsController).to receive(:current_api_v1_user).and_return(nil)
      end

      it "returns an unauthorized status and error message" do
        delete "/api/v1/session"
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No active session found.')
      end
    end

    context "when attempting logout with no active session" do
      before do
        # Manually reset the session state for this context
        reset!
        allow_any_instance_of(Api::V1::SessionsController).to receive(:current_api_v1_user).and_return(nil)
      end

      it "returns an unauthorized status and error message as no user is logged in" do
        delete "/api/v1/session", headers: { 'Authorization': 'invalid_token' } # Token header is irrelevant when session is gone
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No active session found.')
      end
    end
  end
end
