require "rails_helper"

RSpec.describe "Api::V1::Videos", type: :request do
  # We will create the dependent records once for the entire test suite
  # to avoid uniqueness validation errors.
  let!(:admin_user) { FactoryBot.create(:user, is_admin: true) }
  let!(:regular_user) { FactoryBot.create(:user) }

  # Create a single, non-conflicting syllabus and its associations
  let!(:unique_syllabus) { create(:syllabus) }
  let!(:unique_belt) { create(:belt, syllabus: unique_syllabus) }
  let!(:unique_technique_type) do
    create(:technique_type, syllabus: unique_syllabus, belt: unique_belt)
  end

  # Then, create the specific techniques for the tests, ensuring they use
  # our pre-existing, non-conflicting records.
  let!(:technique_a) do
    create(:technique, belt: unique_belt, technique_type: unique_technique_type)
  end
  let!(:technique_b) do
    create(:technique, belt: unique_belt, technique_type: unique_technique_type)
  end

  # Now create the videos, associating them with the non-conflicting techniques.
  let!(:video_a) { FactoryBot.create(:video, technique: technique_a) }
  let!(:video_b) { FactoryBot.create(:video, technique: technique_a) }
  let!(:video_c) { FactoryBot.create(:video, technique: technique_b) }

  # Helper method to parse JSON response body.
  def json_body
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  # Helper to get the top-level 'data' from the JSON:API response.
  def json_resources
    json_body["data"]
  end

  # Helper to get the attributes for a single resource.
  def json_data
    json_body["data"]
  end

  # GET /api/v1/videos
  describe "GET /index" do
    it "returns a successful response and all videos" do
      get api_v1_videos_path, headers: { Accept: "application/json" }
      expect(response).to have_http_status(:ok)
      expect(json_resources.size).to eq(3)
    end

    it "orders the videos by technique_id in descending order" do
      # Create videos with specific technique_ids to ensure deterministic order for testing
      technique_c =
        FactoryBot.create(
          :technique,
          belt: unique_belt,
          technique_type: unique_technique_type
        )
      FactoryBot.create(:video, technique: technique_c) # Create with highest technique_id
      FactoryBot.create(:video, technique: technique_a)
      FactoryBot.create(:video, technique: technique_b)

      get api_v1_videos_path, headers: { Accept: "application/json" }

      sorted_videos = Video.all.order(technique_id: :desc)

      expect(json_resources.map { |v| v["id"].to_i }).to eq(
        sorted_videos.map(&:id)
      )
    end

    context "with filters" do
      it "filters by exact country" do
        # Create additional videos with known countries
        v_can_1 =
          FactoryBot.create(:video, technique: technique_a, country: "Canada")
        v_can_2 =
          FactoryBot.create(:video, technique: technique_b, country: "Canada")
        v_usa_1 =
          FactoryBot.create(:video, technique: technique_a, country: "USA")

        get api_v1_videos_path,
            params: {
              country: "Canada"
            },
            headers: {
              Accept: "application/json"
            }

        expect(response).to have_http_status(:ok)
        countries = json_resources.map { |v| v["attributes"]["country"] }
        expect(countries).to all(eq("Canada"))
        # Ensure we got the newly created Canadian videos without unintentionally matching others
        returned_ids = json_resources.map { |v| v["id"].to_i }
        expect(returned_ids).to include(v_can_1.id, v_can_2.id)
        expect(returned_ids).not_to include(v_usa_1.id)
      end

      it "filters by exact year" do
        v_2019 = FactoryBot.create(:video, technique: technique_a, year: 2019)
        v_2020_a = FactoryBot.create(:video, technique: technique_a, year: 2020)
        v_2020_b = FactoryBot.create(:video, technique: technique_b, year: 2020)

        get api_v1_videos_path,
            params: {
              year: 2020
            },
            headers: {
              Accept: "application/json"
            }

        expect(response).to have_http_status(:ok)
        years = json_resources.map { |v| v["attributes"]["year"] }
        expect(years).to all(eq(2020))
        returned_ids = json_resources.map { |v| v["id"].to_i }
        expect(returned_ids).to include(v_2020_a.id, v_2020_b.id)
        expect(returned_ids).not_to include(v_2019.id)
      end

      it "filters by year range using year_min and year_max" do
        v_2010 = FactoryBot.create(:video, technique: technique_a, year: 2010)
        v_2012 = FactoryBot.create(:video, technique: technique_a, year: 2012)
        v_2015 = FactoryBot.create(:video, technique: technique_b, year: 2015)
        v_2018 = FactoryBot.create(:video, technique: technique_b, year: 2018)

        get api_v1_videos_path,
            params: {
              year_min: 2011,
              year_max: 2015
            },
            headers: {
              Accept: "application/json"
            }

        expect(response).to have_http_status(:ok)
        years = json_resources.map { |v| v["attributes"]["year"] }
        expect(years).to all(be_between(2011, 2015))
        returned_ids = json_resources.map { |v| v["id"].to_i }
        expect(returned_ids).to include(v_2012.id, v_2015.id)
        expect(returned_ids).not_to include(v_2010.id, v_2018.id)
      end
    end
  end

  # GET /api/v1/videos/:id
  describe "GET /show" do
    context "with a valid id" do
      it "returns a successful response and the correct video" do
        get api_v1_video_path(video_a), headers: { Accept: "application/json" }
        expect(response).to have_http_status(:ok)
        expect(json_data["id"].to_i).to eq(video_a.id)
      end

      # New test to check for the correct JSON:API structure
      it "returns the video in the correct JSON:API format" do
        get api_v1_video_path(video_a), headers: { Accept: "application/json" }
        expect(json_data).to include(
          "id",
          "type",
          "attributes",
          "relationships"
        )
        expect(json_data["type"]).to eq("videos")
        expect(json_data["attributes"]).to include("url", "country", "year")
      end

      # New test to ensure the related technique is serialized
      it "includes the related technique data" do
        get api_v1_video_path(video_a), headers: { Accept: "application/json" }
        expect(json_data["relationships"]["technique"]).to be_present
      end
    end

    context "with an invalid id" do
      it "returns a 404 not found response" do
        get api_v1_video_path(id: 999), headers: { Accept: "application/json" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # GET /api/v1/videos/by_technique
  describe "GET /by_technique" do
    it "returns videos for the specified technique" do
      get by_technique_api_v1_videos_path,
          params: {
            technique_id: technique_a.id
          },
          headers: {
            Accept: "application/json"
          }
      expect(response).to have_http_status(:ok)
      expect(json_resources.size).to eq(2)
      expect(json_resources.map { |v| v["attributes"]["technique_id"] }).to all(
        eq(technique_a.id)
      )
    end

    it "returns an empty array if no videos match" do
      get by_technique_api_v1_videos_path,
          params: {
            technique_id: 999
          },
          headers: {
            Accept: "application/json"
          }
      expect(response).to have_http_status(:ok)
      expect(json_resources).to be_empty
    end
  end

  # POST /api/v1/videos
  describe "POST /create" do
    let(:valid_params) do
      { video: FactoryBot.attributes_for(:video, technique_id: technique_a.id) }
    end

    context "with valid parameters" do
      before { sign_in admin_user }
      it "creates a new video and returns a 201 created status" do
        expect {
          post api_v1_videos_path, params: valid_params, as: :json
        }.to change(Video, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      # New test to ensure unpermitted attributes are ignored
      it "ignores unpermitted parameters" do
        params_with_extra =
          valid_params.deep_merge(
            video: {
              is_admin: true,
              some_extra_field: "ignored"
            }
          )
        post api_v1_videos_path, params: params_with_extra, as: :json
        expect(response).to have_http_status(:created)
        expect(Video.last).not_to respond_to(:is_admin)
      end
    end

    context "with invalid parameters" do
      before { sign_in admin_user }
      let(:invalid_params) do
        { video: { url: "", country: "", year: "invalid" } }
      end

      it "does not create a video and returns a 422 unprocessable entity status" do
        expect {
          post api_v1_videos_path, params: invalid_params, as: :json
        }.to_not change(Video, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      # New test to be more specific about the error messages
      it "returns specific error messages for invalid attributes" do
        post api_v1_videos_path, params: invalid_params, as: :json
        expect(json_body["errors"]["url"]).to include("can't be blank")
        expect(json_body["errors"]["country"]).to include("can't be blank")
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in regular_user }
      it "returns a 403 forbidden status" do
        post api_v1_videos_path, params: { video: {} }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 unauthorized status" do
        post api_v1_videos_path, params: { video: {} }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PATCH /api/v1/videos/:id
  describe "PATCH /update" do
    let(:video_to_update) { FactoryBot.create(:video) }

    context "with valid parameters" do
      before { sign_in admin_user }
      let(:new_url) { "https://www.youtube.com/watch?v=updated_vid_123" }
      it "updates the video and returns a 200 ok status" do
        patch api_v1_video_path(video_to_update),
              params: {
                video: {
                  url: new_url
                }
              },
              as: :json
        expect(response).to have_http_status(:ok)
        video_to_update.reload
        expect(video_to_update.url).to eq(new_url)
      end

      # New test to ensure unpermitted attributes are ignored
      it "ignores unpermitted parameters" do
        params_with_extra = {
          video: {
            url: "http://new-url.com",
            is_admin: true
          }
        }
        patch api_v1_video_path(video_to_update),
              params: params_with_extra,
              as: :json
        video_to_update.reload
        expect(video_to_update).not_to respond_to(:is_admin)
      end
    end

    context "with invalid parameters" do
      before { sign_in admin_user }
      it "does not update the video and returns a 422 unprocessable entity status" do
        old_url = video_to_update.url
        patch api_v1_video_path(video_to_update),
              params: {
                video: {
                  url: ""
                }
              },
              as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        video_to_update.reload
        expect(video_to_update.url).to eq(old_url)
      end

      # New test to be more specific about the error messages
      it "returns specific error messages for invalid attributes" do
        patch api_v1_video_path(video_to_update),
              params: {
                video: {
                  year: ""
                }
              },
              as: :json
        expect(json_body["errors"]["year"]).to include("can't be blank")
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in regular_user }
      it "returns a 403 forbidden status" do
        patch api_v1_video_path(video_to_update),
              params: {
                video: {
                }
              },
              as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 unauthorized status" do
        patch api_v1_video_path(video_to_update),
              params: {
                video: {
                }
              },
              as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an invalid id" do
      before { sign_in admin_user }
      it "returns a 404 not found response" do
        patch api_v1_video_path(id: 999), params: { video: {} }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # DELETE /api/v1/videos/:id
  describe "DELETE /destroy" do
    let!(:video_to_delete) { FactoryBot.create(:video) }

    context "when authenticated as an admin" do
      before { sign_in admin_user }
      it "deletes the video and returns a 204 no content status" do
        expect {
          delete api_v1_video_path(video_to_delete), as: :json
        }.to change(Video, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end

      it "returns a 404 not found status if video does not exist" do
        delete api_v1_video_path(id: 999), as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in regular_user }
      it "returns a 403 forbidden status" do
        delete api_v1_video_path(video_to_delete), as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns a 401 unauthorized status" do
        delete api_v1_video_path(video_to_delete), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
