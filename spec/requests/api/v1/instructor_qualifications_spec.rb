# This spec tests the API endpoints for InstructorQualification resources.
# It uses Devise test helpers to handle user authentication and authorization checks.
require "rails_helper"

RSpec.describe "Api::V1::InstructorQualifications", type: :request do
  # Include Devise test helpers for API requests
  include Devise::Test::IntegrationHelpers

  # Create an admin user and a non-admin user for testing authorization rules.
  let!(:admin_user) { create(:user, is_admin: true) }
  let!(:non_admin_user) { create(:user, is_admin: false) }
  let!(:other_user) { create(:user, is_admin: false) }

  # Create the necessary associated records for the tests.
  let!(:belt) { create(:belt) }
  let!(:qualification) { create(:qualification, belt: belt) }
  let!(:belt_grade) { create(:belt_grade, user: admin_user, belt: belt) }
  let!(:instructor_qualification) do
    create(
      :instructor_qualification,
      user: admin_user,
      belt: belt,
      qualification: qualification,
      belt_grade: belt_grade
    )
  end
  let!(:other_user_qualification) do
    create(
      :instructor_qualification,
      user: other_user,
      belt: belt,
      qualification: qualification,
      belt_grade: belt_grade
    )
  end

  # Define valid and invalid parameters for POST and PUT requests.
  let(:valid_attributes) do
    {
      instructor_qualification: {
        achieved_at: 1.day.ago,
        user_id: non_admin_user.id, # This user_id should be ignored by the controller
        belt_id: belt.id,
        belt_grade_id: belt_grade.id,
        qualification_id: qualification.id
      }
    }
  end
  # This is the change: use a permitted attribute that will fail validation
  let(:invalid_attributes) do
    { instructor_qualification: { qualification_id: nil } }
  end
  let(:update_attributes) do
    { instructor_qualification: { achieved_at: 1.year.ago } }
  end

  # Helper method to parse the JSON response body
  def json_response
    json = JSON.parse(response.body)
    json["data"]
  rescue JSON::ParserError
    nil
  end

  # --- GET /index ---
  describe "GET /index" do
    before do
      create(
        :instructor_qualification,
        user: non_admin_user,
        belt: belt,
        qualification: qualification,
        belt_grade: belt_grade
      )
      create(
        :instructor_qualification,
        user: other_user,
        belt: belt,
        qualification: qualification,
        belt_grade: belt_grade
      )
    end

    context "when a user is authenticated" do
      before { sign_in non_admin_user }

      it "returns only the current user's instructor qualifications" do
        get api_v1_instructor_qualifications_path, as: :json
        expect(response).to have_http_status(:success)
        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(
          non_admin_user.instructor_qualifications.count
        )
        owners = json_response.map { |d| d["attributes"]["user_id"] }.uniq
        expect(owners).to eq([non_admin_user.id])
      end
    end

    context "when an admin is authenticated" do
      before { sign_in admin_user }

      it "returns all instructor qualifications" do
        get api_v1_instructor_qualifications_path, as: :json
        expect(response).to have_http_status(:success)
        expect(json_response.length).to eq(InstructorQualification.count)
      end
    end

    context "when a user is not authenticated" do
      it "returns an unauthorized response" do
        get api_v1_instructor_qualifications_path, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # --- GET /show ---
  describe "GET /show" do
    context "when the record exists and the requester is the owner" do
      before { sign_in non_admin_user }

      let!(:own_belt_grade) do
        create(:belt_grade, user: non_admin_user, belt: belt)
      end
      let!(:own_iq) do
        create(
          :instructor_qualification,
          user: non_admin_user,
          belt: belt,
          qualification: qualification,
          belt_grade: own_belt_grade
        )
      end

      it "returns the instructor qualification" do
        get api_v1_instructor_qualification_path(own_iq), as: :json
        expect(response).to have_http_status(:success)
        expect(json_response["id"]).to eq(own_iq.id.to_s)
      end
    end

    context "when authenticated as a different user" do
      before { sign_in other_user }

      it "returns forbidden with standardized error shape" do
        get api_v1_instructor_qualification_path(instructor_qualification),
            as: :json
        expect(response).to have_http_status(:forbidden)
        error_payload = JSON.parse(response.body)
        expect(error_payload).to eq({ "error" => "Unauthorized" })
      end
    end

    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      it "returns the record for any user" do
        get api_v1_instructor_qualification_path(instructor_qualification),
            as: :json
        expect(response).to have_http_status(:success)
        expect(json_response["id"]).to eq(instructor_qualification.id.to_s)
      end
    end

    context "when the record does not exist" do
      before { sign_in non_admin_user }

      it "returns not found with standardized error shape" do
        get api_v1_instructor_qualification_path(id: 999_999), as: :json
        expect(response).to have_http_status(:not_found)
        error_payload = JSON.parse(response.body)
        expect(error_payload).to eq(
          { "status" => 404, "errors" => { "msg" => "Record Not Found" } }
        )
      end
    end

    context "when unauthenticated" do
      it "returns unauthorized" do
        get api_v1_instructor_qualification_path(instructor_qualification),
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # --- POST /create ---
  describe "POST /create" do
    context "when the user is an admin" do
      before { sign_in admin_user }

      context "with valid parameters" do
        it "creates a new instructor qualification" do
          expect {
            post api_v1_instructor_qualifications_path,
                 params: valid_attributes,
                 as: :json
          }.to change(InstructorQualification, :count).by(1)
          expect(response).to have_http_status(:created)
        end

        # NEW TEST: Ensure the qualification is created for the authenticated user, ignoring params[:user_id].
        it "assigns the qualification to the current authenticated user" do
          post api_v1_instructor_qualifications_path,
               params: valid_attributes,
               as: :json
          expect(InstructorQualification.last.user_id).to eq(admin_user.id)
        end
      end

      context "with invalid parameters" do
        it "does not create a new instructor qualification" do
          expect {
            post api_v1_instructor_qualifications_path,
                 params: invalid_attributes,
                 as: :json
          }.to_not change(InstructorQualification, :count)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when the user is not an admin" do
      before { sign_in non_admin_user }

      it "returns a forbidden status" do
        post api_v1_instructor_qualifications_path,
             params: valid_attributes,
             as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the user is not signed in" do
      it "returns an unauthorized status" do
        post api_v1_instructor_qualifications_path,
             params: valid_attributes,
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # --- PUT /update ---
  describe "PUT /update" do
    context "when the user is an admin" do
      before { sign_in admin_user }

      context "with valid parameters" do
        it "updates the requested instructor qualification" do
          put api_v1_instructor_qualification_path(instructor_qualification),
              params: update_attributes,
              as: :json
          instructor_qualification.reload
          expect(instructor_qualification.achieved_at.to_date).to eq(
            update_attributes[:instructor_qualification][:achieved_at].to_date
          )
          expect(response).to have_http_status(:ok)
        end

        # NEW TEST: Ensure an admin can update another user's qualification.
        it "updates another user's qualification" do
          put api_v1_instructor_qualification_path(other_user_qualification),
              params: update_attributes,
              as: :json
          other_user_qualification.reload
          expect(other_user_qualification.achieved_at.to_date).to eq(
            update_attributes[:instructor_qualification][:achieved_at].to_date
          )
          expect(response).to have_http_status(:ok)
        end
      end

      context "with invalid parameters" do
        it "returns an unprocessable entity status" do
          put api_v1_instructor_qualification_path(instructor_qualification),
              params: invalid_attributes,
              as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when the user is not an admin" do
      before { sign_in non_admin_user }

      it "returns a forbidden status with standardized error shape" do
        put api_v1_instructor_qualification_path(instructor_qualification),
            params: update_attributes,
            as: :json
        expect(response).to have_http_status(:forbidden)
        error_payload = JSON.parse(response.body)
        expect(error_payload).to eq({ "error" => "Unauthorized" })
      end
    end

    context "when the user is not signed in" do
      it "returns an unauthorized status" do
        put api_v1_instructor_qualification_path(instructor_qualification),
            params: update_attributes,
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # --- DELETE /destroy ---
  describe "DELETE /destroy" do
    context "when the user is an admin" do
      before { sign_in admin_user }

      it "deletes the instructor qualification" do
        expect {
          delete api_v1_instructor_qualification_path(instructor_qualification),
                 as: :json
        }.to change(InstructorQualification, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end

      # NEW TEST: Ensure an admin can delete another user's qualification.
      it "deletes another user's qualification" do
        expect {
          delete api_v1_instructor_qualification_path(other_user_qualification),
                 as: :json
        }.to change(InstructorQualification, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the user is not an admin" do
      before { sign_in non_admin_user }

      it "returns a forbidden status with standardized error shape" do
        delete api_v1_instructor_qualification_path(instructor_qualification),
               as: :json
        expect(response).to have_http_status(:forbidden)
        error_payload = JSON.parse(response.body)
        expect(error_payload).to eq({ "error" => "Unauthorized" })
      end
    end

    context "when the user is not signed in" do
      it "returns an unauthorized status" do
        delete api_v1_instructor_qualification_path(instructor_qualification),
               as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
