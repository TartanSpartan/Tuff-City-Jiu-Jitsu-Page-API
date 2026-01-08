# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Syllabi", type: :request do
  # This includes Devise helpers for controller and request specs.
  include Devise::Test::IntegrationHelpers

  # Create an admin and a regular user for testing different authorization levels.
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }
  # Create a syllabus without a user for public actions.
  let!(:public_syllabus) { create(:syllabus, :with_belts) }

  # Helper to parse JSON response.
  def json
    JSON.parse(response.body)
  end

  # Helper to get the `data` key from the JSON:API response.
  def json_data
    json["data"]
  end

  # ---
  # GET #index
  # ---
  describe "GET /index" do
    it "returns a list of syllabi with a 200 status code" do
      get api_v1_syllabi_path
      expect(response).to have_http_status(:ok)
      expect(json_data.size).to eq(1)
      expect(json_data.first["type"]).to eq("syllabi")
    end

    it "returns syllabi ordered by ID ascending" do
      # Create a new syllabus with a different ID and unique attributes.
      create(:syllabus, id: 9999, country: "AU", year: 2024)
      get api_v1_syllabi_path
      expect(json_data.map { |s| s["id"].to_i }).to eq(
        Syllabus.order(id: :asc).pluck(:id)
      )
    end
  end

  # ---
  # GET #show
  # ---
  describe "GET /show" do
    context "when the record exists" do
      it "returns a 200 status code" do
        get api_v1_syllabus_path(public_syllabus)
        expect(response).to have_http_status(:ok)
      end

      it "returns the correct syllabus with its relationships" do
        get api_v1_syllabus_path(public_syllabus)
        expect(json_data["id"]).to eq(public_syllabus.id.to_s)
        expect(json_data["attributes"]["country"]).to eq(
          public_syllabus.country
        )
        expect(json_data["relationships"]["belts"]["data"].size).to eq(8)
        expect(
          json_data["relationships"]["technique_types"]["data"].size
        ).to eq(9)
      end
    end

    context "when the record does not exist" do
      it "returns a 404 status code" do
        get api_v1_syllabus_path(id: 999)
        expect(response).to have_http_status(:not_found)
        expect(json["status"]).to eq(404)
        expect(json["errors"]["msg"]).to eq("Record Not Found")
      end
    end
  end

  # ---
  # POST #create
  # ---
  describe "POST /create" do
    let!(:syllabus) { create(:syllabus, country: "DE", year: 2025) }
    let(:valid_params) { { syllabus: { country: "US", year: 2024 } } }

    context "when authenticated as an admin" do
      before { sign_in admin }

      it "creates a new syllabus with valid parameters" do
        expect do post api_v1_syllabi_path, params: valid_params end.to change(
          Syllabus,
          :count
        ).by(1)

        expect(response).to have_http_status(:created)
        expect(json_data["attributes"]["country"]).to eq("US")
      end

      it "does not create a syllabus with invalid parameters" do
        invalid_params = { syllabus: { country: nil, year: 2024 } }
        expect do
          post api_v1_syllabi_path, params: invalid_params
        end.to_not change(Syllabus, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["status"]).to eq(422)
      end

      it "does not create a syllabus with a non-unique country and year combination" do
        duplicate_params = {
          syllabus: {
            country: syllabus.country,
            year: syllabus.year
          }
        }
        expect do
          post api_v1_syllabi_path, params: duplicate_params
        end.to_not change(Syllabus, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a 403 Forbidden status and does not create a syllabus" do
        expect do
          post api_v1_syllabi_path, params: valid_params
        end.to_not change(Syllabus, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 Unauthorized status and does not create a syllabus" do
        expect do
          post api_v1_syllabi_path, params: valid_params
        end.to_not change(Syllabus, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---
  # PATCH #update
  # ---
  describe "PATCH /update" do
    let!(:syllabus) { create(:syllabus, country: "FI", year: 2026) }
    let(:new_country) { "AU" }
    let(:valid_params) { { syllabus: { country: new_country, year: 2025 } } }

    context "when authenticated as an admin" do
      before { sign_in admin }

      it "updates the syllabus with valid parameters" do
        patch api_v1_syllabus_path(syllabus), params: valid_params
        expect(response).to have_http_status(:ok)
        syllabus.reload
        expect(syllabus.country).to eq(new_country)
        expect(json_data["attributes"]["country"]).to eq(new_country)
      end

      it "does not update the syllabus with invalid parameters" do
        invalid_params = { syllabus: { country: nil, year: 2025 } }
        patch api_v1_syllabus_path(syllabus), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        syllabus.reload
        expect(syllabus.country).to_not be_nil
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a 403 Forbidden status and does not update the syllabus" do
        original_country = syllabus.country
        patch api_v1_syllabus_path(syllabus), params: valid_params
        syllabus.reload
        expect(syllabus.country).to eq(original_country)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 Unauthorized status and does not update the syllabus" do
        original_country = syllabus.country
        patch api_v1_syllabus_path(syllabus), params: valid_params
        syllabus.reload
        expect(syllabus.country).to eq(original_country)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the record does not exist" do
      before { sign_in admin }
      it "returns a 404 Not Found status code" do
        patch api_v1_syllabus_path(id: 999), params: valid_params
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---
  # DELETE #destroy
  # ---
  describe "DELETE /destroy" do
    let!(:syllabus) { create(:syllabus, country: "NO", year: 2027) }

    context "when authenticated as an admin" do
      before do
        sign_in admin
        syllabus
      end

      it "deletes the syllabus" do
        expect do delete api_v1_syllabus_path(syllabus) end.to change(
          Syllabus,
          :count
        ).by(-1)
        expect(response).to have_http_status(:no_content)
        expect { syllabus.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when authenticated as a regular user" do
      before do
        sign_in user
        syllabus
      end

      it "returns a 403 Forbidden status and does not delete the syllabus" do
        expect do delete api_v1_syllabus_path(syllabus) end.to_not change(
          Syllabus,
          :count
        )
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 Unauthorized status and does not delete the syllabus" do
        expect do delete api_v1_syllabus_path(syllabus) end.to_not change(
          Syllabus,
          :count
        )
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the record does not exist" do
      before { sign_in admin }
      it "returns a 404 Not Found status code" do
        delete api_v1_syllabus_path(id: 999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
