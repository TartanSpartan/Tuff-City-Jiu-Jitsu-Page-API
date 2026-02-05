require 'rails_helper'

RSpec.describe 'user_grade_syllabus cache and HTTP caching', type: :request do
  it 'returns 304 when If-None-Match matches ETag' do
    syllabus = create(:syllabus, :with_belts)
    belts = syllabus.belts.to_a
    belts.each do |belt|
      tt = create(:technique_type, belt: belt, syllabus: syllabus)
      create_list(:technique, 2, technique_type: tt)
    end

    user = create(:user)

    allow_any_instance_of(Api::V1::SyllabiController).to receive(:authenticate_api_v1_user!).and_return(true)
    allow_any_instance_of(Api::V1::SyllabiController).to receive(:current_api_v1_user).and_return(user)

    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      # Warm synchronously to populate fragments and top-level cache
      WarmSyllabusCacheJob.perform_now(syllabus.id, user.id)

      get "/api/v1/syllabi/#{syllabus.id}/user_grade_syllabus"
      expect(response).to have_http_status(:ok)

      etag = response.headers['ETag'] || response.headers['Etag']
      expect(etag).to be_present

      # Subsequent request with matching If-None-Match should be 304
      get "/api/v1/syllabi/#{syllabus.id}/user_grade_syllabus", headers: { 'If-None-Match' => etag }
      expect(response).to have_http_status(:not_modified)
    ensure
      Rails.cache = old_cache
    end
  end
end
