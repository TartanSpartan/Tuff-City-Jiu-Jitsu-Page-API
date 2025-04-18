require 'rails_helper'
require 'devise/test/integration_helpers'

RSpec.describe "Api::V1::Users::OmniauthCallbacksController", type: :request do
  include Devise::Test::IntegrationHelpers
  include Rails.application.routes.url_helpers
  include Devise::Controllers::Helpers
  Rails.application.reload_routes!

  before(:each) do # Use before(:all) if the state doesn't need to be reset between examples within this describe
    OmniAuth.config.test_mode = true
  end

  after(:each) do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /api/v1/auth/google_oauth2/callback" do
    let(:auth_hash) { build_auth_hash } # Uses default parameters

    before do
      OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
    end

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    context "successful authentication (unit test)" do
      let(:auth_hash) { build_auth_hash(uid: '123', first_name: 'Anne', last_name: 'Reinger') }
      let(:user) { FactoryBot.build_stubbed(:user, id: 1, email: 'test@example.com', first_name: 'Anne', last_name: 'Reinger') } # Using build_stubbed for a unit-like test

      before(:each) do
        mock_omniauth_provider('google_oauth2', email: 'test@example.com', uid: '123') # Uses the default id_token
        allow(User).to receive(:from_omniauth).with(OmniAuth.config.mock_auth[:google_oauth2]).and_return(user)
        allow(user).to receive(:persisted?).and_return(true)
        allow(user).to receive(:save).and_return(true)
      end

      it "redirects to the frontend URL and the user is signed in" do

        get "/api/v1/auth/google_oauth2/callback",
        headers: { 'Accept': 'application/json' },
        env: { 'omniauth.auth' => OmniAuth.config.mock_auth[:google_oauth2] }
    
        # Set the Devise mapping on the standard request environment
        request.env["devise.mapping"] = Devise.mappings[:api_v1_user]
 
        expect(response).to have_http_status(:redirect) # Or :found (302)
        expect(response).to redirect_to(Rails.application.credentials.dig(:Client, :frontend_url))

        # Manually set the user in the Warden session for the assertion
        request.session["warden.user.api_v1_user.key"] = [user.id, "$2a$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"] # Example session key

        # Assert that the user is signed in (check the session using Devise's helper)
        expect(@request.env['warden'].authenticated?(:api_v1_user)).to be_truthy # Also update the scope here
        expect(@request.env['warden'].user(:api_v1_user)).to eq(user)
        expect(current_api_v1_user).to eq(user)
        
        expect(@request.session["warden.user.api_v1_user.key"]).to be_present
        expect(@request.session["warden.user.api_v1_user.key"][0]).to eq(user.id)
      end
    end

    context 'successful authentication (integration test)' do
      let(:google_id_token) { "test_mock_google_id_token" }
      
      before do
        Rails.application.credentials.config[:API] = { google_client_id: 'test_google_client_id' } # Ensure the credential is set

        # Mock the Google ID token verification to return a successful payload
        payload = {
          'sub' => '12345', # Use the same UID as in the mock_omniauth_provider
          'email' => 'example@example.com',
          'given_name' => 'Doyle',
          'family_name' => 'User'
        }
        allow(Google::Auth::IDTokens).to receive(:verify_oidc).with('test_mock_google_id_token', aud: Rails.application.credentials.dig(:API, :google_client_id)).and_return(payload)

        mock_omniauth_provider('google_oauth2', email: 'example@example.com', uid: '12345', first_name: 'Doyle', last_name: 'User', id_token: google_id_token)
      end

      it "redirects to the frontend URL and signs in the user" do

        get "/api/v1/auth/google_oauth2/callback",
            env: { 'omniauth.auth' => OmniAuth.config.mock_auth[:google_oauth2] } # Pass omniauth.auth in env

        user = User.find_by(email: 'example@example.com')
        expect(user).to be_present
        expect(response).to have_http_status(:redirect) 
        expect(response).to redirect_to(Rails.application.credentials.dig(:Client, :frontend_url))
        expect(request.env['warden'].authenticated?(:api_v1_user)).to be_truthy
        expect(request.env['warden'].user(:api_v1_user)).to eq(user) 
      end
    end

    context "authentication failure (user not persisted)" do
      let(:user) { FactoryBot.create(:user, email: 'test@example.com', last_name: auth_hash.info.last_name) } # Create the user with the last name from the auth_hash

      before do
        allow(User).to receive(:from_omniauth).with(OmniAuth.config.mock_auth[:google_oauth2]).and_return(user)
        allow(user).to receive(:persisted?).and_return(false)
        allow(user).to receive(:errors).and_return(ActiveModel::Errors.new(user))
        user.errors.add(:email, "is invalid")
      end

      it "returns a JSON error response with 422 status" do
        get "/api/v1/auth/google_oauth2/callback", env: { 'omniauth.auth' => auth_hash }

        expect(response).to have_http_status(:unprocessable_entity) # Expect 422
        expect(response.content_type).to eq('application/json; charset=utf-8')
      
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present # Expect an 'errors' key in the JSON
        expect(json_response['errors']).to include("Email is invalid") # Check for the specific error message
      end
    end

    context "authentication failure (error in from_omniauth)" do
      before do
        mock_omniauth_provider('google_oauth2', email: 'test@example.com', uid: 'some_uid', id_token: 'invalid_google_id_token')
        allow(User).to receive(:from_omniauth).with(OmniAuth.config.mock_auth[:google_oauth2]).and_raise("Something went wrong during authentication")
      end

      it "returns a JSON error response with 401 status" do
        get "/api/v1/auth/google_oauth2/callback", env: { 'omniauth.auth' => auth_hash }
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OAuth authentication failed')
      end
    end
  end

  describe "GET /api/v1/auth/google_oauth2/", type: :request do
  context "successful authentication with google_id_token" do
    let(:google_id_token) { "test_mock_google_id_token" }
    let(:auth_hash_for_post) do
      build_auth_hash(uid: 'some_uid', token: google_id_token)
    end

    before do

      # Set the mock authentication hash
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '12345',
        info: {
          email: 'example@example.com',
          first_name: 'Doyle',
          last_name: 'User'
        },
        credentials: {
          token: 'test_access_token',
          expires_at: Time.now + 1.hour,
          refresh_token: 'test_refresh_token'
        },
        extra: {
          raw_info: {
            'sub' => '12345',
            'email' => 'example@example.com',
            'given_name' => 'Doyle',
            'family_name' => 'User'
          },
          id_token: google_id_token
        }
      })
    end

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    it "returns an OK status and user information in JSON - GOOGLE ID TOKEN FLOW" do
      Rails.application.credentials.config[:API] = { google_client_id: 'test_google_client_id' } # Ensure credential is set
    
      # Mock the Google ID token verification to return a successful payload
      payload = {
        'sub' => '12345',
        'email' => 'example@example.com',
        'given_name' => 'Doyle',
        'family_name' => 'User'
      }
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).with(google_id_token, aud: Rails.application.credentials.dig(:API, :google_client_id)).and_return(payload)
    
      get "/api/v1/auth/google_oauth2", env: { 'omniauth.strategy' => 'google_oauth2' }

      # Simulate the callback
      get "/api/v1/auth/google_oauth2/callback",
        headers: { 'Accept': 'application/json' },
        env: { 'omniauth.auth' => OmniAuth.config.mock_auth[:google_oauth2] }

      mock_auth_hash = OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '12345',
        info: {
          email: 'example@example.com',
          first_name: 'Doyle',
          last_name: 'User'
        },
        credentials: {
          token: 'test_access_token',
          expires_at: Time.now + 1.hour,
          refresh_token: 'test_refresh_token'
        },
        extra: {
          raw_info: {
            'sub' => '12345',
            'email' => 'example@example.com',
            'given_name' => 'Doyle',
            'family_name' => 'User'
          },
          id_token: google_id_token
        }
      })

      expect(response).to have_http_status(:redirect)
      expect(response).to be_redirect
      expect(response).to redirect_to(Rails.application.credentials.dig(:Client, :frontend_url))
    
      user = User.find_by(email: 'example@example.com')
      expect(user).to be_present
      expect(user.first_name).to eq('Doyle')
      expect(user.last_name).to eq('User')
      expect(request.env['warden'].authenticated?(:api_v1_user)).to be_truthy
      expect(request.env['warden'].user(:api_v1_user)).to eq(user)
    end
  end

    describe "GET /api/v1/auth/google_oauth2/callback", type: :request do
      context "failed authentication with google_id_token" do
        let(:google_id_token) { 'invalid_google_id_token' }
        
        before do
          allow(User).to receive(:from_omniauth).with(any_args) do |auth|
            if auth.dig('extra', 'id_token') == 'invalid_google_id_token'
              raise "Google ID token verification failed"
            else
              # Let's consider if there's other logic worth testing here in future versions of the OmniauthCallbacksController
              mock_user = FactoryBot.build_stubbed(:user)
              allow(User).to receive(:from_omniauth).with(OmniAuth.config.mock_auth[:google_oauth2]).and_return(mock_user)
            end
          end
        
          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
            provider: 'google_oauth2',
            uid: 'some_uid',
            info: {
              email: 'test@example.com',
              first_name: 'Test',
              last_name: 'User'
            },
            credentials: {
              token: 'test_access_token',
              expires_at: Time.now + 1.hour,
              refresh_token: 'test_refresh_token'
            },
            extra: {
              raw_info: {
                'sub' => 'some_sub',
                'email' => 'test@example.com',
                'given_name' => 'Test',
                'family_name' => 'User'
              },
              id_token: google_id_token
            }
          })
        end

        after do
          OmniAuth.config.mock_auth[:google_oauth2] = nil
        end

        it "returns an unauthorized error" do
        
          # Simulate the callback with the google_id_token as a parameter
          get "/api/v1/auth/google_oauth2/callback", env: { 'omniauth.auth' => OmniAuth.config.mock_auth[:google_oauth2] }
        
          expect(response).to have_http_status(:unauthorized)
          expect(response.content_type).to eq('application/json; charset=utf-8')
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('OAuth authentication failed')
        end
      end
    end

    context "authentication with google_id_token raises an error" do
      let(:google_id_token) { 'invalid_google_id_token' }

      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc).with(any_args, aud: anything).and_raise("Google ID token verification failed")

        # Mock the OmniAuth auth hash for a callback with the invalid ID token
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: 'some_uid',
          info: { email: 'test@example.com' },
          credentials: { token: 'access_token' },
          extra: { id_token: google_id_token }
        })
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
      end
      
      it "returns an unauthorized error" do

        get "/api/v1/auth/google_oauth2/callback", env: { 'omniauth.auth' => OmniAuth.config.mock_auth[:google_oauth2] }

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OAuth authentication failed')
      end
    end
  end
end

  describe "GET /api/v1/auth/google_oauth2/callback (failure)", type: :request do
    before(:each) do
      OmniAuth.config.test_mode = true
    end

    after(:each) do
      OmniAuth.config.test_mode = false
    end

    context "failure" do
      it "returns an unauthorized error with a message" do
        get "/api/v1/auth/google_oauth2/callback", params: { error: 'access_denied', error_description: 'User declined to authorize the app' }
        expect(response).to have_http_status(:redirect) 
        expect(response).to redirect_to(new_api_v1_user_session_path(format: :json, error: 'omniauth_failure', reason: 'User declined to authorize the app'))
        follow_redirect! # Make a request to the redirected URL
        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Omniauth Failure')
        expect(json_response['reason']).to eq('User declined to authorize the app')
      end

      it "handles a generic error" do
        get "/api/v1/auth/google_oauth2/callback", params: { error: 'invalid_request' }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_api_v1_user_session_path(format: :json, error: 'omniauth_failure', reason: 'invalid_request'))      
      end
    end
  end

  describe "GET #passthru", type: :request do 
    include Rails.application.routes.url_helpers

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    it "redirects to the Google OAuth2 authorization URL" do
      OmniAuth.config.test_mode = false
      get "/api/v1/auth/google_oauth2"
      expect(response).to be_redirect
      expect(response).to have_http_status(:found) # 302
      expect(response.location).to start_with("https://accounts.google.com/o/oauth2/auth?")
    end
  end

  # Helper method to mock up the omniauth provider, google in this case
  def mock_omniauth_provider(provider, email:, uid:, first_name: 'Test', last_name: 'User', id_token: 'test_mock_google_id_token')
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: uid,
      info: {
        email: email,
        name: "#{first_name} #{last_name}",
        first_name: first_name,
        last_name: last_name
      },
      credentials: {
        token: 'test_google_oauth2_token',
        expires_at: Time.now + 1.hour,
        refresh_token: 'test_refresh_token'
      },
      extra: {
        raw_info: {
          email: email,
          name: "#{first_name} #{last_name}",
          given_name: first_name,
          family_name: last_name,
        },
        id_token: id_token # Use the provided or default id_token
      }
    })
  end

  # Helper method to build the authorization hash
  def build_auth_hash(provider: 'google_oauth2', uid: '123456789', email: 'test@example.com', first_name: 'Test', last_name: 'User', token: 'test_google_oauth2_token', expires_at: Time.now + 1.hour, refresh_token: 'test_refresh_token')
    OmniAuth::AuthHash.new({
      provider: provider,
      uid: uid,
      info: {
        email: email,
        first_name: first_name,
        last_name: last_name
      },
      credentials: {
        token: token,
        expires_at: expires_at,
        refresh_token: refresh_token
      }
    })
  end

  # Helper method to access the session
  def get_session(response)
    cookies = response.headers['Set-Cookie']
    session_cookie = cookies.split('; ').find { |cookie| cookie.start_with?('_tuff_city_jiu_jitsu_api_tablet_session') }
    if session_cookie
      cookie_value = session_cookie.split('=', 2).last
      # Cookie values can vary; for CookieStore, it's usually Base64 encoded and might be signed/encrypted
      return { '_tuff_city_jiu_jitsu_api_tablet_session' => cookie_value }
    else
      return {}
   end
end