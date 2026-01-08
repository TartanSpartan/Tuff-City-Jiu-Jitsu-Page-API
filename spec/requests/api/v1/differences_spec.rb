require "rails_helper"

RSpec.describe "Api::V1::Differences", type: :request do
  # Use `let` to define objects that will be used in multiple tests.
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:difference) { create(:difference) }
  let(:other_difference) { create(:difference) }

  # Helper method to parse JSON API responses
  def json
    JSON.parse(response.body)["data"]
  end

  # Test the index action
  describe "GET /api/v1/differences" do
    before do
      # Create multiple differences to test the order
      create_list(:difference, 3)
      # The controller requires authentication for index; sign in an admin
      sign_in admin
      get "/api/v1/differences"
    end

    it "returns a successful response" do
      expect(response).to have_http_status(:success)
    end

    it "returns all differences ordered by technique_id descending" do
      # Access the 'data' key from the parsed JSON.
      expect(json.count).to eq(Difference.count)
      # Verify the ordering is correct.
      expect(
        json.first["relationships"]["technique"]["data"]["id"].to_i
      ).to be >= json.last["relationships"]["technique"]["data"]["id"].to_i
    end
  end

  # Test the show action
  describe "GET /api/v1/differences/:id" do
    context "when the difference exists" do
      before do
        sign_in admin
        get "/api/v1/differences/#{difference.id}"
      end

      it "returns a successful response" do
        expect(response).to have_http_status(:success)
      end

      it "returns the correct difference" do
        # Access the 'data' key from the parsed JSON.
        difference_json = JSON.parse(response.body)["data"]
        expect(difference_json["id"].to_i).to eq(difference.id)
        expect(difference_json["attributes"]["content"]).to eq(
          difference.content
        )
      end
    end

    context "when the difference does not exist" do
      before do
        sign_in admin
        get "/api/v1/differences/999"
      end

      it "returns a not found response" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # Test the create action
  describe "POST /api/v1/differences" do
    # Create the associated records first for the valid attributes.
    let!(:technique) { create(:technique) }
    let!(:compared_to_technique) { create(:technique) }
    let(:valid_attributes) do
      attributes_for(
        :difference,
        technique_id: technique.id,
        compared_to_technique_id: compared_to_technique.id
      )
    end
    let(:invalid_attributes) { attributes_for(:difference, content: nil) }
    let(:self_comparison_attributes) do
      attributes_for(
        :difference,
        technique_id: technique.id,
        compared_to_technique_id: technique.id
      )
    end

    context "when authenticated as an admin" do
      before { sign_in admin }

      context "with valid parameters" do
        it "creates a new difference" do
          expect {
            post "/api/v1/differences", params: { difference: valid_attributes }
          }.to change(Difference, :count).by(1)
        end

        it "returns a created status" do
          post "/api/v1/differences", params: { difference: valid_attributes }
          expect(response).to have_http_status(:created)
        end
      end

      context "with invalid parameters" do
        it "does not create a new difference" do
          expect {
            post "/api/v1/differences",
                 params: {
                   difference: invalid_attributes
                 }
          }.to_not change(Difference, :count)
        end

        it "returns an unprocessable entity status" do
          post "/api/v1/differences", params: { difference: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "when a technique is compared to itself" do
        it "does not create a new difference" do
          expect {
            post "/api/v1/differences",
                 params: {
                   difference: self_comparison_attributes
                 }
          }.to_not change(Difference, :count)
        end

        it "returns an unprocessable entity status" do
          post "/api/v1/differences",
               params: {
                 difference: self_comparison_attributes
               }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(
            "A technique cannot be compared to itself"
          )
        end
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized status" do
        post "/api/v1/differences", params: { difference: valid_attributes }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden status" do
        post "/api/v1/differences", params: { difference: valid_attributes }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Test the update action
  describe "PUT /api/v1/differences/:id" do
    let(:new_attributes) { { content: "This is the new content." } }
    let(:invalid_attributes) { { content: nil } }

    context "when authenticated as an admin" do
      before { sign_in admin }

      context "with valid parameters" do
        before do
          put "/api/v1/differences/#{difference.id}",
              params: {
                difference: new_attributes
              }
        end

        it "updates the requested difference" do
          difference.reload
          expect(difference.content).to eq(new_attributes[:content])
        end

        it "returns a successful status" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "with invalid parameters" do
        before do
          put "/api/v1/differences/#{difference.id}",
              params: {
                difference: invalid_attributes
              }
        end

        it "does not update the difference" do
          difference.reload
          expect(difference.content).to_not eq(invalid_attributes[:content])
        end

        it "returns an unprocessable entity status" do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized status" do
        put "/api/v1/differences/#{difference.id}",
            params: {
              difference: new_attributes
            }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden status" do
        put "/api/v1/differences/#{difference.id}",
            params: {
              difference: new_attributes
            }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Test the destroy action
  describe "DELETE /api/v1/differences/:id" do
    context "when authenticated as an admin" do
      before do
        sign_in admin
        # Need to create a record right before the test to ensure it exists.
        difference
      end

      it "destroys the difference" do
        expect { delete "/api/v1/differences/#{difference.id}" }.to change(
          Difference,
          :count
        ).by(-1)
      end

      it "returns a no content status" do
        delete "/api/v1/differences/#{difference.id}"
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized status" do
        delete "/api/v1/differences/#{difference.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden status" do
        delete "/api/v1/differences/#{difference.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Test the custom `by_technique` action
  describe "GET /api/v1/differences/by_technique/:technique_id" do
    let!(:technique1) { create(:technique) }
    let!(:technique2) { create(:technique) }
    let!(:difference1) do
      create(
        :difference,
        technique: technique1,
        compared_to_technique: technique2
      )
    end
    let!(:difference2) do
      create(
        :difference,
        technique: technique1,
        compared_to_technique: create(:technique)
      )
    end
    let!(:difference3) { create(:difference, technique: technique2) }

    context "when differences for the technique exist" do
      before { get "/api/v1/differences/by_technique/#{technique1.id}" }

      it "returns a successful response" do
        expect(response).to have_http_status(:success)
      end

      it "returns only the differences for the specified technique" do
        expect(json.count).to eq(2)
        expect(json.map { |d| d["id"].to_i }).to contain_exactly(
          difference1.id,
          difference2.id
        )
      end

      it "includes the full associated records in the response" do
        get "/api/v1/differences/by_technique/#{technique1.id}",
            params: {
              include: "technique,compared_to_technique"
            }
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key("included")
        expect(parsed_response["included"].count).to eq(3) # one technique1 and two others
      end
    end

    context "when no differences for the technique exist" do
      before { get "/api/v1/differences/by_technique/999" } # A non-existent ID

      it "returns a successful response" do
        expect(response).to have_http_status(:success)
      end

      it "returns an empty array" do
        expect(json).to be_empty
      end
    end
  end
end
