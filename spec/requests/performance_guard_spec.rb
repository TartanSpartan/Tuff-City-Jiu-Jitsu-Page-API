require 'rails_helper'

RSpec.describe 'Syllabi performance guard', type: :request do
  it 'keeps SQL query count for show and user_grade_syllabus under threshold' do
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
    sql_count = 0
    subscriber = ->(_name, _start, _finish, _id, payload) do
      sql = payload[:sql].to_s
      sql_count += 1 if sql.present? && sql !~ /ROLLBACK|BEGIN|COMMIT/
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      begin
        get "/api/v1/syllabi/#{syllabus.id}"
        get "/api/v1/syllabi/#{syllabus.id}/user_grade_syllabus"
      ensure
        Rails.cache = old_cache
      end
    end

    # Choose a generous threshold; tune as needed
    expect(sql_count).to be <= 80
  end
end
