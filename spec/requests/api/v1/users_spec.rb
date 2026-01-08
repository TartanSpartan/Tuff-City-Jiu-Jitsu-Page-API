# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::UsersController, type: :request do
  # This helper method provides a valid authentication token for testing.
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let!(:white_belt) { create(:belt, colour: "White") }
  let!(:unqualified_qualification) do
    create(:qualification, level: "No qualifications")
  end

  # Ensure canonical qualification rows with stable IDs exist so that
  # controller code which normalizes qualification IDs (and relies on
  # effective_qualification_id) doesn't hit FK constraint failures in tests.
  before do
    levels = [
      "No qualifications",
      "Assistant instructor",
      "Instructor",
      "Club instructor"
    ]
    levels.each_with_index do |lvl, idx|
      Qualification.create_with(
        level: lvl,
        belt: white_belt
      ).find_or_create_by!(id: idx + 1)
    end
  end

  # Test for the `current` action.
  describe "GET /current" do
    context "when the user is authenticated" do
      before do
        sign_in user
        # Correct path for the 'current' action
        get "/api/v1/users/current"
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the correct user data" do
        json_response = JSON.parse(response.body)
        expect(json_response["id"]).to eq(user.id)
        expect(json_response["first_name"]).to eq(user.first_name)
      end
    end

    context "when the user is not authenticated" do
      before do
        # Correct path for the 'current' action
        get "/api/v1/users/current"
      end

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test for the `index` action.
  describe "GET /index" do
    before do
      create_list(:user, 3) # Create some users for testing
    end

    context "when an admin is authenticated" do
      before do
        sign_in admin_user
        get "/api/v1/users"
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all users" do
        json_response = JSON.parse(response.body)
        expect(json_response.count).to eq(User.count)
      end
    end

    context "when a non-admin is authenticated" do
      before do
        sign_in user
        get "/api/v1/users"
      end

      it "returns a forbidden response" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the user is not authenticated" do
      before { get "/api/v1/users" }

      it "returns an unauthorized response" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test for the `create` action.
  describe "POST /create" do
    context "with valid parameters" do
      let(:user_params) { FactoryBot.attributes_for(:user) }

      it "creates a new user and associated records in a single transaction" do
        expect do
          post "/api/v1/users", params: { user: user_params }
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user).to be_present

        # Verify that the new user has a belt grade and that it is a 'White' belt.
        expect(new_user.current_belt_grade).to be_present
        expect(new_user.current_belt_grade.belt.colour).to eq("White")
      end

      it "returns a created status and the user ID" do
        post "/api/v1/users", params: { user: user_params }
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:created)
        expect(json_response["id"]).to eq(User.last.id)
        expect(json_response["message"]).to eq(
          "User created and signed in successfully"
        )
      end
    end

    context "with invalid parameters" do
      it "does not create a new user" do
        expect do
          post "/api/v1/users", params: { user: { email: "", password: "123" } }
        end.to_not change(User, :count)
      end

      it "returns an unprocessable entity status" do
        post "/api/v1/users", params: { user: { email: "", password: "123" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # Test for the `show` action.
  describe "GET /show" do
    let(:other_user) { create(:user) }

    context "when an admin is authenticated" do
      before do
        sign_in admin_user
        get "/api/v1/users/#{other_user.id}"
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the user data" do
        json_response = JSON.parse(response.body)
        expect(json_response["id"]).to eq(other_user.id)
      end
    end

    context "when the owner is authenticated" do
      before do
        sign_in user
        get "/api/v1/users/#{user.id}"
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the user data" do
        json_response = JSON.parse(response.body)
        expect(json_response["id"]).to eq(user.id)
      end
    end

    context "when a different user is authenticated" do
      before do
        sign_in user
        get "/api/v1/users/#{other_user.id}"
      end

      it "returns a forbidden response" do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Test for the `email_available` action.
  describe "GET /email_available" do
    context "when the email is available" do
      before do
        # Correct path for the 'email_available' action
        get "/api/v1/users/email_available",
            params: {
              email: "newemail@example.com"
            }
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns available as true" do
        json_response = JSON.parse(response.body)
        expect(json_response["available"]).to be(true)
      end
    end

    context "when the email is already taken" do
      let!(:existing_user) { create(:user, email: "taken@example.com") }

      before do
        # Correct path for the 'email_available' action
        get "/api/v1/users/email_available",
            params: {
              email: "taken@example.com"
            }
      end

      it "returns a success response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns available as false" do
        json_response = JSON.parse(response.body)
        expect(json_response["available"]).to be(false)
      end
    end
  end

  # Test for the `update` action.
  describe "PATCH /update" do
    let!(:user_to_update) { create(:user) }
    let!(:new_belt) { create(:belt, colour: "Light Blue") }

    context "when an admin is authenticated" do
      before { sign_in admin_user }

      it "updates the user basic information" do
        new_first_name = "NewFirstName"
        patch "/api/v1/users/#{user_to_update.id}",
              params: {
                user: {
                  first_name: new_first_name
                }
              }
        user_to_update.reload
        expect(user_to_update.first_name).to eq(new_first_name)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # Test for the `destroy` action.
  describe "DELETE /destroy" do
    let!(:user_to_delete) { create(:user) }

    context "when an admin is authenticated" do
      it "deletes the user" do
        sign_in admin_user
        expect do delete "/api/v1/users/#{user_to_delete.id}" end.to change(
          User,
          :count
        ).by(-1)
      end

      it "returns a no content status" do
        sign_in admin_user
        delete "/api/v1/users/#{user_to_delete.id}"
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when a non-admin is authenticated" do
      it "does not delete the user" do
        sign_in user
        expect do delete "/api/v1/users/#{user_to_delete.id}" end.to_not change(
          User,
          :count
        )
      end
    end
  end
end
