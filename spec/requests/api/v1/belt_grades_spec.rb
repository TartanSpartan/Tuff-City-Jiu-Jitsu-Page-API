# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BeltGrades", type: :request do
  include Rails.application.routes.url_helpers

  # Regular user for actions not requiring admin privileges
  let(:user) { create(:user) }
  # Another regular user to test access control
  let(:other_user) { create(:user) }
  # Admin user for actions requiring admin privileges
  let(:admin_user) { create(:user, is_admin: true) }

  let!(:belt_1) { create(:belt, colour: "Yellow") }
  let!(:belt_2) { create(:belt, colour: "Orange") }
  let!(:belt_grade_user) { create(:belt_grade, user: user, belt: belt_1) }
  let!(:belt_grade_other_user) do
    create(:belt_grade, user: other_user, belt: belt_2)
  end

  # Test the GET /index action
  describe "GET /index" do
    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a successful response with a list of belt grades for the current user" do
        get api_v1_belt_grades_path

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["data"].length).to eq(1)

        returned_belt_grade = json_response["data"].first
        expect(returned_belt_grade["id"]).to eq(belt_grade_user.id.to_s)
      end
    end

    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      it "returns all belt grades" do
        get api_v1_belt_grades_path

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["data"].length).to eq(BeltGrade.count)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized response" do
        get api_v1_belt_grades_path

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the GET /show/:id action
  describe "GET /show" do
    context "when authenticated as the owner" do
      before { sign_in user }

      it "returns a successful response with the correct belt grade" do
        get api_v1_belt_grade_path(belt_grade_user)

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["id"].to_i).to eq(belt_grade_user.id)
        expect(json_response["data"]["attributes"]["belt_id"]).to eq(
          belt_grade_user.belt_id
        )
      end
    end

    context "when authenticated as a different user" do
      before { sign_in other_user }

      it "returns a forbidden response" do
        get api_v1_belt_grade_path(belt_grade_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      it "returns a successful response for any belt grade" do
        get api_v1_belt_grade_path(belt_grade_user)

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["id"].to_i).to eq(belt_grade_user.id)
      end
    end

    context "when the record does not exist" do
      before { sign_in user }
      it "returns a not found response" do
        get api_v1_belt_grade_path(id: 9999)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized response" do
        get api_v1_belt_grade_path(belt_grade_user)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the POST /create action
  describe "POST /create" do
    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      context "with valid parameters" do
        it "creates a new belt grade and returns a created response" do
          new_belt_grade_params = {
            belt_grade: {
              user_id: user.id,
              belt_id: belt_1.id,
              obtained_at: 1.day.ago
            }
          }
          expect {
            post api_v1_belt_grades_path,
                 params: new_belt_grade_params,
                 as: :json
          }.to change(BeltGrade, :count).by(1)

          expect(response).to have_http_status(:created)
        end
      end

      context "with invalid parameters" do
        it "returns an unprocessable entity status and errors" do
          post api_v1_belt_grades_path,
               params: {
                 belt_grade: {
                   user_id: nil,
                   belt_id: nil
                 }
               },
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response["errors"]).to be_present
        end
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden response" do
        new_belt_grade_params = {
          belt_grade: {
            user_id: user.id,
            belt_id: belt_1.id,
            obtained_at: 1.day.ago
          }
        }
        post api_v1_belt_grades_path, params: new_belt_grade_params, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized response" do
        new_belt_grade_params = {
          belt_grade: {
            user_id: user.id,
            belt_id: belt_1.id,
            obtained_at: 1.day.ago
          }
        }
        post api_v1_belt_grades_path, params: new_belt_grade_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the PUT /update/:id action
  describe "PUT /update" do
    let!(:belt_grade) { create(:belt_grade, user: user, belt: belt_1) }

    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      context "when the update is successful" do
        it "updates the record and returns a successful response" do
          new_obtained_at = 1.day.ago.to_date
          put api_v1_belt_grade_path(belt_grade),
              params: {
                belt_grade: {
                  obtained_at: new_obtained_at
                }
              },
              as: :json

          expect(response).to have_http_status(:success)
          belt_grade.reload
          expect(belt_grade.obtained_at.to_date).to eq(new_obtained_at)
        end
      end

      context "when the update fails due to invalid parameters" do
        it "returns an unprocessable entity status and errors" do
          put api_v1_belt_grade_path(belt_grade),
              params: {
                belt_grade: {
                  obtained_at: nil
                }
              },
              as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response["errors"]).to be_present
        end
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden response" do
        put api_v1_belt_grade_path(belt_grade),
            params: {
              belt_grade: {
                obtained_at: 1.day.ago.to_date
              }
            },
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized response" do
        put api_v1_belt_grade_path(belt_grade),
            params: {
              belt_grade: {
                obtained_at: 1.day.ago.to_date
              }
            },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Test the DELETE /destroy/:id action
  describe "DELETE /destroy" do
    let!(:belt_grade) { create(:belt_grade, user: user, belt: belt_1) }

    context "when authenticated as an admin user" do
      before { sign_in admin_user }

      context "when the record exists" do
        it "deletes the belt grade and returns a 204 No Content status" do
          expect { delete api_v1_belt_grade_path(belt_grade) }.to change(
            BeltGrade,
            :count
          ).by(-1)

          expect(response).to have_http_status(:no_content)
        end
      end

      context "when the record does not exist" do
        it "returns a not found response" do
          delete api_v1_belt_grade_path(id: 9999)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns a forbidden response" do
        delete api_v1_belt_grade_path(belt_grade)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns an unauthorized response" do
        delete api_v1_belt_grade_path(belt_grade)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
