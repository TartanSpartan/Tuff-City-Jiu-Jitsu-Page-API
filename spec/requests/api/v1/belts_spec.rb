# frozen_string_literal: true

require "rails_helper"

# RSpec request tests for Api::V1::BeltsController
RSpec.describe Api::V1::BeltsController, type: :request do
  include Rails.application.routes.url_helpers

  let(:admin_user) { create(:user, is_admin: true) }
  let(:non_admin_user) { create(:user, is_admin: false) }

  before do
    # Default to an admin user for request specs that need elevated privileges.
    sign_in admin_user
  end

  after { sign_out admin_user }

  # Test non-nested actions first.
  describe "Non-nested Belt Actions" do
    # Test the index action (GET /api/v1/belts) - Non-nested
    describe "GET #index (non-nested)" do
      it "returns a successful response" do
        create(:belt)
        get api_v1_belts_path
        expect(response).to be_successful
      end

      it "returns all belts ordered by id ascending" do
        belt1 = create(:belt, colour: "White")
        belt2 = create(:belt, colour: "Light Blue")
        belt3 = create(:belt, colour: "Brown")
        belt4 = create(:belt, colour: "Green")
        get api_v1_belts_path
        parsed_response = JSON.parse(response.body)
        returned_ids =
          parsed_response["data"].map { |belt_data| belt_data["id"].to_i }
        expect(returned_ids).to eq(Belt.order(:id).pluck(:id))
      end

      it "renders the belts using the BeltSerializer" do
        belt = create(:belt, colour: "White")
        get api_v1_belts_path
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["data"]).to be_an(Array)
        expect(parsed_response["data"].first["attributes"]).to include(
          "colour" => "White"
        )
        expect(parsed_response["data"].count).to eq(Belt.count)
      end
    end

    # Test the create action (POST /api/v1/belts) - Non-nested
    describe "POST #create (non-nested)" do
      context "with valid parameters" do
        it "creates a new Belt" do
          valid_attributes = attributes_for(:belt, colour: "Purple")
          # Use a valid, recognized colour for search testing
          search_belt = create(:belt, colour: "Purple")
          expect {
            post api_v1_belts_path, params: { belt: valid_attributes }
          }.to change(Belt, :count).by(1)
        end

        it "returns a 201 Created status" do
          valid_attributes = attributes_for(:belt, colour: "Purple")
          post api_v1_belts_path, params: { belt: valid_attributes }
          expect(response).to have_http_status(:created)
        end

        it "renders the created belt as JSON" do
          valid_attributes = attributes_for(:belt, colour: "Purple")
          post api_v1_belts_path, params: { belt: valid_attributes }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]["attributes"]).to include(
            "colour" => "Purple"
          )
        end
      end

      context "with invalid parameters" do
        it "does not create a new Belt" do
          invalid_attributes = attributes_for(:belt, colour: nil)
          expect {
            post api_v1_belts_path, params: { belt: invalid_attributes }
          }.to_not change(Belt, :count)
        end

        it "returns a 422 Unprocessable Entity status" do
          invalid_attributes = attributes_for(:belt, colour: nil)
          post api_v1_belts_path, params: { belt: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders the validation errors as JSON" do
          invalid_attributes = attributes_for(:belt, colour: nil)
          post api_v1_belts_path, params: { belt: invalid_attributes }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 422)
          expect(parsed_response["errors"]).to be_an(Array)
          expect(parsed_response["errors"].first).to include(
            "field" => "colour",
            "message" => "can't be blank"
          )
        end
      end
    end

    # Test the show action (GET /api/v1/belts/:id) - Non-nested
    describe "GET #show (non-nested)" do
      context "when the belt exists" do
        it "returns a successful response" do
          belt = create(:belt)
          get api_v1_belt_path(belt)
          expect(response).to be_successful
        end

        it "renders the belt as JSON using the BeltSerializer" do
          belt = create(:belt)
          get api_v1_belt_path(belt)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]).to include("id" => belt.id.to_s)
          expect(parsed_response["data"]["attributes"]).to include(
            "colour" => belt.colour
          )
        end
      end

      context "when the belt does not exist" do
        it "returns a 404 Not Found status" do
          get api_v1_belt_path(id: 999_999)
          expect(response).to have_http_status(:not_found)
        end

        it "renders a not found error message as JSON" do
          get api_v1_belt_path(id: 999_999)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end
    end

    # Test the destroy action (DELETE /api/v1/belts/:id) - Non-nested
    describe "DELETE #destroy (non-nested)" do
      context "when the belt exists" do
        it "destroys the Belt" do
          belt = create(:belt)
          expect { delete api_v1_belt_path(belt) }.to change(Belt, :count).by(
            -1
          )
        end

        it "returns a 204 No Content status" do
          belt = create(:belt)
          delete api_v1_belt_path(belt)
          expect(response).to have_http_status(:no_content)
        end

        it "returns an empty response body" do
          belt = create(:belt)
          delete api_v1_belt_path(belt)
          expect(response.body).to be_empty
        end
      end

      context "when the belt does not exist" do
        it "does not destroy any Belt" do
          expect { delete api_v1_belt_path(id: 999_999) }.to_not change(
            Belt,
            :count
          )
        end

        it "returns a 404 Not Found status" do
          delete api_v1_belt_path(id: 999_999)
          expect(response).to have_http_status(:not_found)
        end

        it "renders a not found error message as JSON" do
          delete api_v1_belt_path(id: 999_999)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end
    end

    # Test the custom find action (GET /api/v1/belts_find)
    describe "GET #find (custom route)" do
      context "with search parameters" do
        it "returns belts matching the search criteria" do
          # Use a valid colour for search testing
          search_belt = create(:belt, colour: "Purple")
          get api_v1_belts_find_path,
              params: {
                belt: {
                  colour: search_belt.colour
                }
              }
          expect(response).to be_successful
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]).to be_an(Array)
          expect(parsed_response["data"].count).to eq(1)
          expect(parsed_response["data"].first["id"]).to eq(search_belt.id.to_s)
          expect(parsed_response["data"].first["attributes"]["colour"]).to eq(
            search_belt.colour
          )
        end

        it "returns an empty array if no belts match" do
          get api_v1_belts_find_path,
              params: {
                belt: {
                  colour: "NonExistentColour"
                }
              }
          expect(response).to be_successful
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]).to eq([])
        end
      end

      context "without search parameters" do
        it "returns all belts" do
          create_list(:belt, 3)
          get api_v1_belts_find_path
          expect(response).to be_successful
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"].count).to eq(Belt.count)
          expect(
            parsed_response["data"].map { |belt| belt["id"] }
          ).to contain_exactly(*Belt.pluck(:id).map(&:to_s))
        end
      end

      context "when user is not authenticated" do
        it "returns a 401 Unauthorized status" do
          sign_out admin_user
          get api_v1_belts_find_path, params: { belt: { colour: "AnyColour" } }
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  # Now, test the nested actions.
  describe "Nested Belt Actions (/syllabi/:syllabus_id/belts)" do
    # Test the nested index action (GET /api/v1/syllabi/:syllabus_id/belts)
    describe "GET #index (nested)" do
      it "returns a successful response" do
        syllabus = create(:syllabus)
        get api_v1_syllabus_belts_path(syllabus_id: syllabus.id)
        expect(response).to be_successful
      end

      it "returns only belts associated with the specified syllabus" do
        syllabus = create(:syllabus)
        belt_in_syllabus = create(:belt, syllabus: syllabus)
        belt_not_in_syllabus = create(:belt, syllabus: create(:syllabus))
        get api_v1_belts_find_path,
            params: {
              belt: {
                colour: "NonExistentColour"
              }
            }
        get api_v1_syllabus_belts_path(syllabus_id: syllabus.id)
        parsed_response = JSON.parse(response.body)
        returned_ids =
          parsed_response["data"].map { |belt_data| belt_data["id"].to_i }
        expect(returned_ids).to contain_exactly(belt_in_syllabus.id)
      end
    end

    # Test the nested create action (POST /api/v1/syllabi/:syllabus_id/belts)
    describe "POST #create (nested)" do
      context "with valid parameters" do
        it "creates a new Belt associated with the syllabus" do
          syllabus = create(:syllabus)
          nested_valid_attributes = attributes_for(:belt, colour: "Orange")
          expect {
            post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
                 params: {
                   belt: nested_valid_attributes
                 }
          }.to change(Belt, :count).by(1)

          created_belt = Belt.last
          expect(created_belt.syllabus).to eq(syllabus)
        end

        it "returns a 201 Created status" do
          syllabus = create(:syllabus)
          nested_valid_attributes = attributes_for(:belt, colour: "Orange")
          post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
               params: {
                 belt: nested_valid_attributes
               }
          expect(response).to have_http_status(:created)
        end

        it "renders the created belt as JSON" do
          syllabus = create(:syllabus)
          nested_valid_attributes = attributes_for(:belt, colour: "Orange")
          post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
               params: {
                 belt: nested_valid_attributes
               }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]["attributes"]).to include(
            "colour" => "Orange"
          )
        end
      end

      context "with invalid parameters" do
        it "does not create a new Belt" do
          syllabus = create(:syllabus)
          nested_invalid_attributes = attributes_for(:belt, colour: nil)
          expect {
            post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
                 params: {
                   belt: nested_invalid_attributes
                 }
          }.to_not change(Belt, :count)
        end

        it "returns a 422 Unprocessable Entity status" do
          syllabus = create(:syllabus)
          nested_invalid_attributes = attributes_for(:belt, colour: nil)
          post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
               params: {
                 belt: nested_invalid_attributes
               }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders the validation errors as JSON" do
          syllabus = create(:syllabus)
          nested_invalid_attributes = attributes_for(:belt, colour: nil)
          post api_v1_syllabus_belts_path(syllabus_id: syllabus.id),
               params: {
                 belt: nested_invalid_attributes
               }
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 422)
          expect(parsed_response["errors"]).to be_an(Array)
          expect(parsed_response["errors"].first).to include(
            "field" => "colour",
            "message" => "can't be blank"
          )
        end
      end
    end

    # Test the nested show action (GET /api/v1/syllabi/:syllabus_id/belts/:id)
    describe "GET #show (nested)" do
      context "when the belt exists and belongs to the syllabus" do
        it "returns a successful response" do
          syllabus = create(:syllabus)
          belt_in_syllabus = create(:belt, syllabus: syllabus)
          get api_v1_syllabus_belt_path(
                syllabus_id: syllabus.id,
                id: belt_in_syllabus.id
              )
          expect(response).to be_successful
        end

        it "renders the belt as JSON" do
          syllabus = create(:syllabus)
          belt_in_syllabus = create(:belt, syllabus: syllabus)
          get api_v1_syllabus_belt_path(
                syllabus_id: syllabus.id,
                id: belt_in_syllabus.id
              )
          parsed_response = JSON.parse(response.body)
          expect(parsed_response["data"]).to include(
            "id" => belt_in_syllabus.id.to_s
          )
          expect(parsed_response["data"]["attributes"]).to include(
            "colour" => belt_in_syllabus.colour
          )
        end
      end

      context "when the belt exists but does not belong to the syllabus" do
        it "returns a 404 Not Found status" do
          syllabus = create(:syllabus)
          belt_in_other_syllabus = create(:belt, syllabus: create(:syllabus))
          get api_v1_syllabus_belt_path(
                syllabus_id: syllabus.id,
                id: belt_in_other_syllabus.id
              )
          expect(response).to have_http_status(:not_found)
        end

        it "renders a not found error message as JSON" do
          syllabus = create(:syllabus)
          belt_in_other_syllabus = create(:belt, syllabus: create(:syllabus))
          get api_v1_syllabus_belt_path(
                syllabus_id: syllabus.id,
                id: belt_in_other_syllabus.id
              )
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end

      context "when the belt does not exist" do
        it "returns a 404 Not Found status" do
          syllabus = create(:syllabus)
          get api_v1_syllabus_belt_path(syllabus_id: syllabus.id, id: 999_999)
          expect(response).to have_http_status(:not_found)
        end

        it "renders a not found error message as JSON" do
          syllabus = create(:syllabus)
          get api_v1_syllabus_belt_path(syllabus_id: syllabus.id, id: 999_999)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end
    end

    # Test the nested destroy action (DELETE /api/v1/syllabi/:syllabus_id/belts/:id)
    describe "DELETE #destroy (nested)" do
      context "when the belt exists and belongs to the syllabus" do
        it "destroys the Belt" do
          syllabus = create(:syllabus)
          belt_to_destroy = create(:belt, syllabus: syllabus)
          expect {
            delete api_v1_syllabus_belt_path(
                     syllabus_id: syllabus.id,
                     id: belt_to_destroy.id
                   )
          }.to change(Belt, :count).by(-1)
        end

        it "returns a 204 No Content status" do
          syllabus = create(:syllabus)
          belt_to_destroy = create(:belt, syllabus: syllabus)
          delete api_v1_syllabus_belt_path(
                   syllabus_id: syllabus.id,
                   id: belt_to_destroy.id
                 )
          expect(response).to have_http_status(:no_content)
        end

        it "returns an empty response body" do
          syllabus = create(:syllabus)
          belt_to_destroy = create(:belt, syllabus: syllabus)
          delete api_v1_syllabus_belt_path(
                   syllabus_id: syllabus.id,
                   id: belt_to_destroy.id
                 )
          expect(response.body).to be_empty
        end
      end

      context "when the belt exists but does not belong to the syllabus" do
        it "returns a 404 Not Found status" do
          syllabus = create(:syllabus)
          belt_in_other_syllabus = create(:belt, syllabus: create(:syllabus))
          delete api_v1_syllabus_belt_path(
                   syllabus_id: syllabus.id,
                   id: belt_in_other_syllabus.id
                 )
          expect(response).to have_http_status(:not_found)
        end

        it "renders a not found error message as JSON" do
          syllabus = create(:syllabus)
          belt_in_other_syllabus = create(:belt, syllabus: create(:syllabus))
          delete api_v1_syllabus_belt_path(
                   syllabus_id: syllabus.id,
                   id: belt_in_other_syllabus.id
                 )
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end

      context "when the belt does not exist" do
        it "does not destroy any Belt" do
          syllabus = create(:syllabus)
          expect {
            delete api_v1_syllabus_belt_path(
                     syllabus_id: syllabus.id,
                     id: 999_999
                   )
          }.to_not change(Belt, :count)
        end

        it "returns a 404 Not Found status" do
          syllabus = create(:syllabus)
          delete api_v1_syllabus_belt_path(
                   syllabus_id: syllabus.id,
                   id: 999_999
                 )
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("status" => 404)
          expect(parsed_response["errors"]).to be_a(Hash)
          expect(parsed_response["errors"]).to include(
            "msg" => "Record Not Found"
          )
        end
      end
    end
  end
end
