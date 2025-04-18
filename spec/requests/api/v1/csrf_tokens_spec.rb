require 'rails_helper'

RSpec.describe "Api::V1::CsrfTokens", type: :request do
  Rails.application.reload_routes!
  describe "GET /api/v1/csrf_token" do 
    it "returns a CSRF token in JSON format" do
      get "/api/v1/csrf_token"

      expect(response).to have_http_status(200)
      expect(response.content_type).to eq('application/json; charset=utf-8')

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('csrf_token')
      expect(json_response['csrf_token']).to be_a(String)
    end
  end

  # The following test is related to the inheritance of the CSRF Tokens controller from the API Application controller
  it "sets the CSRF-TOKEN cookie" do
    get "/api/v1/csrf_token"
    expect(response.cookies).to have_key('CSRF-TOKEN')
    expect(response.cookies['CSRF-TOKEN']).to be_present
  end
end