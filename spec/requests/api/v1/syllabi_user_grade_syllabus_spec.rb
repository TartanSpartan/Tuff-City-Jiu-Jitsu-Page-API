# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Syllabi user_grade_syllabus HTTP caching", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user) }
  let!(:syllabus) { create(:syllabus, :with_belts) }

  def json
    JSON.parse(response.body)
  end

  before do
    # Enable caching for these tests
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

    # Give user a belt grade so they can view the syllabus
    orange_belt = syllabus.belts.find_by(kyu_number: 6)
    create(:belt_grade, user: user, belt: orange_belt, obtained_at: Date.current) if orange_belt

    sign_in user
  end

  describe "GET /api/v1/syllabi/:id/user_grade_syllabus" do
    it "returns 200 OK with JSON:API payload on first request" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["type"]).to eq("syllabi")
      expect(json["data"]["id"]).to eq(syllabus.id.to_s)
    end

    it "sets ETag header" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      expect(response.headers["ETag"]).to be_present
    end

    it "sets Last-Modified header" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Last-Modified"]).to be_present
    end

    it "returns 304 Not Modified when ETag matches" do
      # First request to get the ETag
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      expect(response).to have_http_status(:ok)
      etag = response.headers["ETag"]

      # Second request with If-None-Match header
      get user_grade_syllabus_api_v1_syllabus_path(syllabus),
          headers: { "If-None-Match" => etag }

      expect(response).to have_http_status(:not_modified)
    end

    it "returns 304 Not Modified when If-Modified-Since is recent" do
      # First request to get Last-Modified
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      expect(response).to have_http_status(:ok)
      last_modified = response.headers["Last-Modified"]

      # Second request with If-Modified-Since header
      get user_grade_syllabus_api_v1_syllabus_path(syllabus),
          headers: { "If-Modified-Since" => last_modified }

      expect(response).to have_http_status(:not_modified)
    end

    it "returns 200 OK with fresh data when ETag does not match" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus),
          headers: { "If-None-Match" => '"stale-etag-value"' }

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to be_present
    end

    it "returns 200 OK when If-Modified-Since is older than resource" do
      old_time = 1.year.ago.httpdate

      get user_grade_syllabus_api_v1_syllabus_path(syllabus),
          headers: { "If-Modified-Since" => old_time }

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to be_present
    end

    it "caches the payload and returns it on subsequent requests" do
      Rails.cache.clear

      # First request populates cache
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      expect(response).to have_http_status(:ok)
      first_response_body = response.body

      # Second request should return same payload (from cache)
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(first_response_body)
    end

    it "includes belts in the included array" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      included = json["included"]
      belt_types = included.select { |r| r["type"] == "belts" }
      expect(belt_types).not_to be_empty
    end

    it "includes technique_types in the included array when present" do
      # Create a technique_type for one of the belts
      target_belt = syllabus.belts.find_by(kyu_number: 6)
      create(:technique_type, belt: target_belt, syllabus: syllabus) if target_belt

      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      included = json["included"]
      tt_types = included.select { |r| r["type"] == "technique_types" }
      expect(tt_types).not_to be_empty
    end

    it "does not include duplicate resources in the included array" do
      # Ensure there are some technique_types and techniques present
      belts = syllabus.belts.to_a
      target_belt = belts.sample
      tt = create(:technique_type, belt: target_belt, syllabus: syllabus)
      create(:technique, technique_type: tt)

      get user_grade_syllabus_api_v1_syllabus_path(syllabus)

      expect(response).to have_http_status(:ok)
      included = json["included"] || []
      keys = included.map { |r| "#{r['type']}:#{r['id']}" }
      expect(keys.size).to eq(keys.uniq.size)
    end
  end

  describe "cache invalidation" do
    it "returns different ETag when syllabus is updated" do
      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      original_etag = response.headers["ETag"]

      # Update the syllabus's timestamp explicitly so the cache_key changes
      syllabus.update_column(:updated_at, (syllabus.updated_at || Time.current) + 2.seconds)

      get user_grade_syllabus_api_v1_syllabus_path(syllabus)
      new_etag = response.headers["ETag"]

      expect(new_etag).not_to eq(original_etag)
    end
  end
end
