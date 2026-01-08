# spec/requests/api/v1/techniques_spec.rb
require "rails_helper"

RSpec.describe "Api::V1::Techniques", type: :request do
  let(:admin_user) { create(:user, is_admin: true) }
  let(:non_admin_user) { create(:user, is_admin: false) }

  def json_response
    JSON.parse(response.body)["data"]
  rescue JSON::ParserError
    nil
  end

  def json_error_response
    JSON.parse(response.body)["errors"]
  rescue JSON::ParserError
    nil
  end

  # GET /techniques
  describe "GET /index" do
    let!(:belt_black) { create(:belt, colour: "Brown") }
    let!(:belt_white) { create(:belt, colour: "White") }
    let!(:technique_black) { create(:technique, belt: belt_black) }
    let!(:technique_white) { create(:technique, belt: belt_white) }

    it "returns a successful response" do
      get api_v1_techniques_path
      expect(response).to have_http_status(:success)
    end

    it "renders the correct number of techniques" do
      get api_v1_techniques_path
      expect(json_response.count).to eq(2)
    end

    it "orders techniques by belt_id in descending order" do
      get api_v1_techniques_path
      serialized_belt_ids =
        json_response.map do |tech|
          tech["relationships"]["belt"]["data"]["id"].to_i
        end
      expect(serialized_belt_ids).to eq(
        [belt_black.id, belt_white.id].sort.reverse
      )
    end
  end

  # GET /techniques/:id
  describe "GET /show" do
    let!(:technique) { create(:technique) }

    context "with a valid technique ID" do
      it "returns a successful response" do
        get api_v1_technique_path(technique)
        expect(response).to have_http_status(:success)
      end

      it "renders the correct technique" do
        get api_v1_technique_path(technique)
        expect(json_response["id"]).to eq(technique.id.to_s)
      end
    end

    context "with an invalid technique ID" do
      it "returns a not found response" do
        get api_v1_technique_path(9999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # POST /techniques
  describe "POST /create" do
    let!(:technique_type) { create(:technique_type) }
    let!(:belt) { create(:belt) }

    let(:valid_attributes) do
      {
        summary: "New Technique",
        technique_type_id: technique_type.id,
        belt_id: belt.id,
        videos_attributes: [
          {
            url: "https://www.youtube.com/watch?v=new_video_1",
            country: "CA",
            year: 2023
          },
          {
            url: "https://www.youtube.com/watch?v=new_video_2",
            country: "UK",
            year: 2023
          }
        ]
      }
    end

    context "as an admin user" do
      before { sign_in admin_user }

      it "creates a new technique with nested videos" do
        expect do
          post api_v1_techniques_path,
               params: {
                 technique: valid_attributes
               },
               as: :json
        end.to change(Technique, :count).by(1).and change(Video, :count).by(2)
      end

      it "returns a created status" do
        post api_v1_techniques_path,
             params: {
               technique: valid_attributes
             },
             as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context "as a non-admin user" do
      before { sign_in non_admin_user }

      it "does not create a new technique" do
        expect do
          post api_v1_techniques_path,
               params: {
                 technique: valid_attributes
               },
               as: :json
        end.to_not change(Technique, :count)
      end

      it "returns a forbidden status" do
        post api_v1_techniques_path,
             params: {
               technique: valid_attributes
             },
             as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unauthenticated user" do
      it "returns an unauthenticated status" do
        post api_v1_techniques_path,
             params: {
               technique: valid_attributes
             },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PATCH /techniques/:id
  describe "PATCH /update" do
    let!(:technique) { create(:technique) }

    context "as an admin user" do
      before { sign_in admin_user }

      context "with valid parameters" do
        let!(:video_to_update) { create(:video, technique: technique) }
        let!(:video_to_destroy) { create(:video, technique: technique) }
        let(:new_attributes) do
          {
            summary: "Updated Summary",
            videos_attributes: [
              {
                id: video_to_update.id,
                url: "https://www.youtube.com/watch?v=updated_vid"
              },
              { id: video_to_destroy.id, _destroy: "1" },
              {
                url: "https://www.youtube.com/watch?v=new_video_created",
                country: "US",
                year: 2024
              }
            ]
          }
        end

        it "updates the requested technique and its videos" do
          expect do
            patch api_v1_technique_path(technique),
                  params: {
                    technique: new_attributes
                  },
                  as: :json
          end.to change(Video, :count).by(0)

          technique.reload
          expect(technique.summary).to eq("Updated Summary")
          expect(video_to_update.reload.url).to eq(
            "https://www.youtube.com/watch?v=updated_vid"
          )
          expect(Video.find_by(id: video_to_destroy.id)).to be_nil
          expect(
            technique.videos.find_by(
              url: "https://www.youtube.com/watch?v=new_video_created"
            )
          ).to be_present
        end

        it "returns a successful status" do
          patch api_v1_technique_path(technique),
                params: {
                  technique: new_attributes
                },
                as: :json
          expect(response).to have_http_status(:ok)
        end
      end

      context "with invalid parameters" do
        it "returns an unprocessable entity status" do
          patch api_v1_technique_path(technique),
                params: {
                  technique: {
                    summary: nil
                  }
                },
                as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "as a non-admin user" do
      before { sign_in non_admin_user }

      it "does not update the technique" do
        original_summary = technique.summary
        patch api_v1_technique_path(technique),
              params: {
                technique: {
                  summary: "Attempted Change"
                }
              },
              as: :json
        technique.reload
        expect(technique.summary).to eq(original_summary)
      end

      it "returns a forbidden status" do
        patch api_v1_technique_path(technique),
              params: {
                technique: {
                  summary: "Attempted Change"
                }
              },
              as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unauthenticated user" do
      it "returns an unauthenticated status" do
        patch api_v1_technique_path(technique),
              params: {
                technique: {
                  summary: "Attempted Change"
                }
              },
              as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /techniques/:id
  describe "DELETE /destroy" do
    let!(:technique) { create(:technique) }
    let!(:video_to_destroy) { create(:video, technique: technique) }

    context "as an admin user" do
      before { sign_in admin_user }

      it "destroys the requested technique and its videos" do
        expect do delete api_v1_technique_path(technique) end.to change(
          Technique,
          :count
        ).by(-1).and change(Video, :count).by(-1)
      end

      it "returns a no content status" do
        delete api_v1_technique_path(technique)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "as a non-admin user" do
      before { sign_in non_admin_user }

      it "does not destroy the technique" do
        expect do delete api_v1_technique_path(technique) end.to_not change(
          Technique,
          :count
        )
      end

      it "returns a forbidden status" do
        delete api_v1_technique_path(technique)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unauthenticated user" do
      it "returns an unauthenticated status" do
        delete api_v1_technique_path(technique)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
