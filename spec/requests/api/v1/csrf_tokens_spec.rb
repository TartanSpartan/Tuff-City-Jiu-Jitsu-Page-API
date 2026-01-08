# spec/requests/api/v1/csrf_tokens_spec.rb

require 'rails_helper'

RSpec.describe "Api::V1::CsrfTokens", type: :request do
  describe "GET /api/v1/csrf_token" do
    it "returns a CSRF token in the JSON body and sets a cookie" do
      get "/api/v1/csrf_token"

      # Check response status and format
      expect(response).to have_http_status(200)
      expect(response.content_type).to eq('application/json; charset=utf-8')

      # Check that the JSON body contains a token string
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('csrf_token')
      expect(json_response['csrf_token']).to be_a(String)
      expect(json_response['csrf_token']).to be_present

      # Check that the cookie contains a token string
      expect(response.cookies).to have_key('CSRF-TOKEN')
      expect(response.cookies['CSRF-TOKEN']).to be_a(String)
      expect(response.cookies['CSRF-TOKEN']).to be_present
    end
  end
end
