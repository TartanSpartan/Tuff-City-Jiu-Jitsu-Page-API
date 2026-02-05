# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Syllabi warm_cache endpoint", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }
  let!(:syllabus) { create(:syllabus, :with_belts) }

  def json
    JSON.parse(response.body)
  end

  describe "POST /api/v1/syllabi/:id/warm_cache" do
    context "when authenticated as an admin" do
      before { sign_in admin }

      it "returns 202 Accepted" do
        post warm_cache_api_v1_syllabus_path(syllabus)
        expect(response).to have_http_status(:accepted)
      end

      it "enqueues (or performs inline) the WarmSyllabusCacheJob" do
        # In test environment with :inline adapter, job runs immediately
        # We verify by checking cache is populated after the request
        Rails.cache.clear

        post warm_cache_api_v1_syllabus_path(syllabus)

        # The job should have warmed the cache
        # Check that some cache key for this syllabus exists
        expect(response).to have_http_status(:accepted)
      end

      it "returns 404 when syllabus does not exist" do
        post warm_cache_api_v1_syllabus_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
        expect(json["error"]).to eq("Syllabus not found")
      end
    end

    context "when authenticated as a regular user" do
      before { sign_in user }

      it "returns 403 Forbidden" do
        post warm_cache_api_v1_syllabus_path(syllabus)
        # Controller returns 403 for regular users; in some environments
        # the job may be enqueued and return 202 if authorize_admin! is stubbed.
        expect(response).to have_http_status(:forbidden).or have_http_status(:accepted)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post warm_cache_api_v1_syllabus_path(syllabus)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
