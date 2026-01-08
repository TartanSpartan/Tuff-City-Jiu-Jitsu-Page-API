require "rails_helper"

RSpec.describe "API Base Contracts", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:non_admin_user) { create(:user) }

  let(:valid_waiver_attrs) { attributes_for(:waiver) }
  let(:invalid_waiver_attrs) { attributes_for(:waiver, participant_name: nil) }

  def json_body
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  describe "authentication and authorization" do
    it "returns 401 with standardized payload when unauthenticated" do
      get api_v1_waivers_path
      expect(response).to have_http_status(:unauthorized)
      body = json_body
      expect(body["status"]).to eq(401)
      expect(body["error"]).to eq(
        "User must be logged in to access this resource"
      )
    end

    it "returns 403 with standardized payload when non-admin accesses admin-only endpoint" do
      sign_in non_admin_user
      get api_v1_waivers_path
      expect(response).to have_http_status(:forbidden)
      body = json_body
      expect(body["error"]).to eq("Unauthorized")
    end
  end

  describe "record not found" do
    it "returns 404 with standardized payload" do
      get api_v1_waiver_path("non-existent-id"), as: :json
      expect(response).to have_http_status(:not_found)
      body = json_body
      expect(body["status"]).to eq(404)
      expect(body.dig("errors", "msg")).to eq("Record Not Found")
    end
  end

  describe "validation errors" do
    it "returns 422 with a flat list of messages" do
      sign_in non_admin_user
      post api_v1_waivers_path,
           params: {
             waiver: invalid_waiver_attrs
           },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body["status"]).to eq(422)
      expect(body["errors"]).to be_an(Array)
      expect(body["errors"]).not_to be_empty
    end
  end

  describe "parameter missing (400)" do
    it "returns 400 with standardized payload when required param is missing" do
      sign_in non_admin_user
      # Waivers controller requires :waiver param; send something else
      post api_v1_waivers_path,
           params: {
             bad_param: valid_waiver_attrs
           },
           as: :json
      expect(response).to have_http_status(:bad_request)
      body = json_body
      expect(body["status"]).to eq(400)
      expect(body.dig("errors", "msg")).to eq(
        "param is missing or the value is empty or invalid: waiver"
      )
    end
  end

  describe "internal server error (500)" do
    it "returns 500 with standardized payload for a raised error" do
      get api_v1_trigger_500_path
      expect(response).to have_http_status(:internal_server_error)
      body = json_body
      expect(body["status"]).to eq(500)
      expect(body.dig("errors", "msg")).to match(/^Internal Server Error:/)
    end
  end
end
