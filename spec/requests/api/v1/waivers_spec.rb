require "rails_helper"
# This line will explicitly include the route helpers for this test file.
include Rails.application.routes.url_helpers

# We're changing the type to :request for a more robust test environment.
RSpec.describe "Api::V1::Waivers", type: :request do
  # FactoryBot syntax is already included from rails_helper.rb
  let(:admin_user) { create(:user, :admin) }
  let(:non_admin_user) { create(:user) }
  let(:waiver) { create(:waiver) }
  let(:user_owned_waiver) { create(:waiver, user: non_admin_user) }
  let(:valid_attributes) { attributes_for(:waiver) }
  let(:invalid_attributes) { attributes_for(:waiver, participant_name: nil) }
  let(:json_headers) do
    { "Accept" => "application/json", "Content-Type" => "application/json" }
  end

  # The `sign_in` helper from Devise::Test::IntegrationHelpers works here.

  describe "GET /index" do
    before do
      # Create some waivers to test with
      create_list(:waiver, 3)
    end

    context "when user is an admin" do
      it "returns a list of waivers" do
        sign_in admin_user

        # Request specs use named route helpers, which is a best practice.
        get api_v1_waivers_path

        # We need to check the size of the 'data' array, not the top-level hash.
        expect(JSON.parse(response.body)["data"].size).to eq(3)
        expect(response).to have_http_status(:success)
      end

      it "returns JSON:API resources with type 'waivers' and attributes" do
        sign_in admin_user
        get api_v1_waivers_path
        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body).to include("data")
        expect(body["data"]).to be_an(Array)
        if body["data"].any?
          first = body["data"].first
          expect(first["type"]).to eq("waivers")
          expect(first["attributes"]).to include(
            "participant_name",
            "participant_email_address",
            "initials"
          )
          expect(first).to have_key("relationships")
        end
      end
    end

    context "when user is not an admin" do
      it "returns a forbidden status" do
        sign_in non_admin_user
        get api_v1_waivers_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Waiver" do
        sign_in non_admin_user
        expect {
          post api_v1_waivers_path,
               params: {
                 waiver: valid_attributes
               },
               as: :json
        }.to change(Waiver, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it "associates the waiver with the current user if logged in" do
        sign_in non_admin_user
        post api_v1_waivers_path,
             params: {
               waiver: valid_attributes
             },
             as: :json
        expect(Waiver.last.user).to eq(non_admin_user)
      end

      it "does not associate the waiver with a user if not logged in" do
        post api_v1_waivers_path,
             params: {
               waiver: valid_attributes
             },
             as: :json
        expect(Waiver.last.user).to be_nil
      end
    end

    context "with invalid parameters" do
      it "does not create a new Waiver" do
        sign_in non_admin_user
        expect {
          post api_v1_waivers_path,
               params: {
                 waiver: invalid_attributes
               },
               as: :json
        }.to_not change(Waiver, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns an error for missing waiver parameter" do
        sign_in non_admin_user
        post api_v1_waivers_path,
             params: {
               bad_param: valid_attributes
             },
             as: :json
        puts "Debug output for missing parameter error:"
        body = JSON.parse(response.body)
        puts body
        expect(response).to have_http_status(:bad_request)
        expect(body["status"]).to eq(400)
        expect(body.dig("errors", "msg")).to eq(
          "param is missing or the value is empty or invalid: waiver"
        )
      end
    end
  end

  describe "GET /show" do
    context "when the waiver exists" do
      it "returns a successful response" do
        get api_v1_waiver_path(waiver), as: :json
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON:API resource with type 'waivers' and attributes" do
        get api_v1_waiver_path(waiver), as: :json
        body = JSON.parse(response.body)
        expect(body).to include("data")
        expect(body["data"]["type"]).to eq("waivers")
        expect(body["data"]).to include("attributes")
        expect(body["data"]["attributes"]).to include(
          "participant_name",
          "participant_email_address",
          "initials"
        )
        expect(body["data"]).to have_key("relationships")
      end
    end

    context "when the waiver does not exist" do
      it "returns a not found status with a specific error message" do
        get api_v1_waiver_path("non-existent-id"), as: :json
        puts "Debug output for not found error in SHOW:"
        body = JSON.parse(response.body)
        puts body
        expect(response).to have_http_status(:not_found)
        expect(body["status"]).to eq(404)
        expect(body.dig("errors", "msg")).to eq("Record Not Found")
      end
    end
  end

  describe "PUT /update" do
    context "when user is an admin" do
      it "updates the requested waiver" do
        sign_in admin_user
        put api_v1_waiver_path(waiver),
            params: {
              waiver: {
                participant_name: "New Name"
              }
            },
            as: :json
        waiver.reload
        expect(waiver.participant_name).to eq("New Name")
        expect(response).to have_http_status(:ok)
      end

      it "does not update the waiver with invalid parameters" do
        sign_in admin_user
        original_name = waiver.participant_name
        put api_v1_waiver_path(waiver),
            params: {
              waiver: {
                participant_name: nil
              }
            },
            as: :json
        waiver.reload
        expect(waiver.participant_name).to eq(original_name)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is the owner" do
      it "updates the requested waiver" do
        sign_in user_owned_waiver.user
        put api_v1_waiver_path(user_owned_waiver),
            params: {
              waiver: {
                participant_name: "Updated Name"
              }
            },
            as: :json
        user_owned_waiver.reload
        expect(user_owned_waiver.participant_name).to eq("Updated Name")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not the owner or an admin" do
      it "returns a forbidden status with a specific error message" do
        sign_in non_admin_user
        put api_v1_waiver_path(waiver),
            params: {
              waiver: {
                participant_name: "Denied Name"
              }
            },
            as: :json
        puts "Debug output for forbidden error in UPDATE:"
        body = JSON.parse(response.body)
        puts body
        expect(response).to have_http_status(:forbidden)
        expect(body["error"]).to eq("Unauthorized")
      end
    end

    context "when waiver is not found" do
      it "returns a not found status with a specific error message" do
        sign_in admin_user
        put api_v1_waiver_path("non-existent-id"),
            params: {
              waiver: {
                participant_name: "Name"
              }
            },
            as: :json
        puts "Debug output for not found error in UPDATE:"
        body = JSON.parse(response.body)
        puts body
        expect(response).to have_http_status(:not_found)
        expect(body["status"]).to eq(404)
        expect(body.dig("errors", "msg")).to eq("Record Not Found")
      end
    end
  end

  describe "DELETE /destroy" do
    context "when user is an admin" do
      before { sign_in admin_user }

      it "destroys the requested waiver" do
        waiver_to_destroy = create(:waiver)

        expect {
          delete api_v1_waiver_path(waiver_to_destroy), headers: json_headers
        }.to change(Waiver, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when user is not an admin" do
      before { sign_in non_admin_user }

      it "returns a forbidden status and does not destroy the waiver" do
        waiver_to_keep = create(:waiver)

        expect {
          delete api_v1_waiver_path(waiver_to_keep), headers: json_headers
        }.to_not change(Waiver, :count)

        expect(response).to have_http_status(:forbidden)
        puts "Debug output for forbidden error in DELETE:"
        body = JSON.parse(response.body)
        puts body
        expect(body["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "GET /outstanding_count" do
    it "returns count for admin" do
      sign_in admin_user
      create_list(:waiver, 2)
      get outstanding_count_api_v1_waivers_path
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("outstanding_count")
      expect(body["outstanding_count"]).to be_a(Integer)
    end

    it "returns forbidden for non-admin" do
      sign_in non_admin_user
      get outstanding_count_api_v1_waivers_path
      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Unauthorized")
    end
  end
end
