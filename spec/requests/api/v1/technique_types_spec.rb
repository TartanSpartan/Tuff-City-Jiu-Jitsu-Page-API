require "rails_helper"

RSpec.describe "Api::V1::TechniqueTypes", type: :request do
  let(:admin_user) { create(:user, is_admin: true) }
  let(:non_admin_user) { create(:user, is_admin: false) }

  # A helper method to parse the JSON response body and access the data.
  def json_response
    json = JSON.parse(response.body)
    json.dig("data")
  end

  # Use let! to ensure a syllabus is always created for the belongs_to association.
  let!(:syllabus) { create(:syllabus) }

  # Let the database assign IDs automatically to avoid unique constraint errors.
  let!(:belt_1) { create(:belt, colour: "White") }
  let!(:belt_2) { create(:belt, colour: "Yellow") }
  let!(:belt_3) { create(:belt, colour: "Green") }

  # Create the technique types, associating them with the belts and syllabus.
  let!(:technique_type_1) do
    create(:technique_type, category: "Throw", syllabus: syllabus, belt: belt_1)
  end
  let!(:technique_type_2) do
    create(
      :technique_type,
      category: "Hold Down",
      syllabus: syllabus,
      belt: belt_2
    )
  end
  let!(:technique_type_3) do
    create(
      :technique_type,
      category: "Strike",
      syllabus: syllabus,
      belt: belt_3
    )
  end

  # Test the GET /index action
  describe "GET /index" do
    let!(:belt_black) { create(:belt, colour: "Brown") }
    let!(:belt_white) { create(:belt, colour: "White") }
    let!(:technique_type_black) { create(:technique_type, belt: belt_black) }
    let!(:technique_type_white) { create(:technique_type, belt: belt_white) }

    it "returns a successful response with a list of technique types" do
      get api_v1_technique_types_path

      expect(response).to have_http_status(:success)
      expect(json_response.length).to eq(5)
    end

    it "orders techniques by belt_id in descending order" do
      get api_v1_technique_types_path
      serialized_belt_ids =
        json_response.map do |tt|
          tt.dig("relationships", "belt", "data", "id").to_i
        end
      puts "Expected order: #{[belt_white.id, belt_black.id, belt_3.id, belt_2.id, belt_1.id]}"
      puts "Actual order: #{serialized_belt_ids}"
      expect(serialized_belt_ids).to eq(
        [belt_white.id, belt_black.id, belt_3.id, belt_2.id, belt_1.id]
      )
    end
  end

  # Test the GET /show/:id action
  describe "GET /show" do
    context "when the record exists" do
      it "returns a successful response with the correct technique type" do
        get api_v1_technique_type_path(technique_type_1)

        expect(response).to have_http_status(:success)
        expect(json_response["id"]).to eq(technique_type_1.id.to_s)
        expect(json_response["attributes"]["category"]).to eq(
          technique_type_1.category
        )
      end
    end

    context "when the record does not exist" do
      it "returns a not found response" do
        get api_v1_technique_type_path(id: 9999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # Test the DELETE /destroy/:id action
  describe "DELETE /destroy" do
    let!(:test_tt) { create(:technique_type, :with_techniques, belt: belt_1) }

    context "as an admin user" do
      before { sign_in admin_user }

      it "deletes the technique type and its associated techniques" do
        expect { delete api_v1_technique_type_path(test_tt) }.to change(
          TechniqueType,
          :count
        ).by(-1).and change(Technique, :count).by(-3)
      end

      it "returns a 204 No Content status" do
        delete api_v1_technique_type_path(test_tt)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "as a non-admin user" do
      before { sign_in non_admin_user }

      it "does not delete the technique type" do
        initial_count = TechniqueType.count
        delete api_v1_technique_type_path(test_tt)
        final_count = TechniqueType.count
        puts "Initial TechniqueType count: #{initial_count}"
        puts "Final TechniqueType count: #{final_count}"
        expect(final_count).to eq(initial_count)
      end

      it "returns a forbidden status" do
        delete api_v1_technique_type_path(test_tt)
        puts "Actual response status: #{response.status}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unauthenticated user" do
      it "does not delete the technique type" do
        expect { delete api_v1_technique_type_path(test_tt) }.to_not change(
          TechniqueType,
          :count
        )
      end

      it "returns an unauthorized status" do
        delete api_v1_technique_type_path(test_tt)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the PUT /update/:id action
  describe "PUT /update" do
    context "as an admin user" do
      before { sign_in admin_user }

      context "when the update is successful" do
        it "updates the record and returns a successful response" do
          new_category = "Locking"
          put api_v1_technique_type_path(technique_type_1),
              params: {
                technique_type: {
                  category: new_category
                }
              },
              as: :json

          expect(response).to have_http_status(:ok)
          technique_type_1.reload
          expect(technique_type_1.category).to eq(new_category)
        end
      end

      context "when the update fails due to invalid parameters" do
        it "returns an unprocessable entity status and errors" do
          put api_v1_technique_type_path(technique_type_1),
              params: {
                technique_type: {
                  category: nil
                }
              },
              as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response["errors"]).not_to be_empty
        end
      end
    end

    context "as a non-admin user" do
      before { sign_in non_admin_user }

      it "does not update the record" do
        original_category = technique_type_1.category
        put api_v1_technique_type_path(technique_type_1),
            params: {
              technique_type: {
                category: "Attempted Change"
              }
            },
            as: :json
        technique_type_1.reload
        puts "Original category: #{original_category}"
        puts "Updated category: #{technique_type_1.category}"
        expect(technique_type_1.category).to eq(original_category)
      end

      it "returns a forbidden status" do
        put api_v1_technique_type_path(technique_type_1),
            params: {
              technique_type: {
                category: "Attempted Change"
              }
            },
            as: :json
        puts "Actual response status: #{response.status}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unauthenticated user" do
      it "does not update the record" do
        original_category = technique_type_1.category
        put api_v1_technique_type_path(technique_type_1),
            params: {
              technique_type: {
                category: "Attempted Change"
              }
            },
            as: :json
        technique_type_1.reload
        expect(technique_type_1.category).to eq(original_category)
      end

      it "returns an unauthorized status" do
        put api_v1_technique_type_path(technique_type_1),
            params: {
              technique_type: {
                category: "Attempted Change"
              }
            },
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the GET /search action
  describe "GET /search" do
    it "returns a list of technique types that match the search query" do
      get search_api_v1_technique_types_path, params: { query: "Throw" }

      expect(response).to have_http_status(:success)
      expect(json_response.length).to eq(1)
      expect(json_response.first["attributes"]["category"]).to eq("Throw")
    end

    it "returns case-insensitive matches" do
      get search_api_v1_technique_types_path, params: { query: "throw" }

      expect(response).to have_http_status(:success)
      expect(json_response.length).to eq(1)
      expect(json_response.first["attributes"]["category"]).to eq("Throw")
    end

    it "returns an empty list when no matches are found" do
      get search_api_v1_technique_types_path, params: { query: "NonExistent" }

      expect(response).to have_http_status(:success)
      expect(json_response).to be_empty
    end
  end
end
