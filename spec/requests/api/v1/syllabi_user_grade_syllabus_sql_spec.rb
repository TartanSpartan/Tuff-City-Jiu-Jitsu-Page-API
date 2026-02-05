require 'rails_helper'

RSpec.describe 'GET /api/v1/syllabi/:id/user_grade_syllabus (SQL)', type: :request do
  it 'does not issue per-belt technique_types queries' do
    syllabus = create(:syllabus, :with_belts)

    # ensure technique_types and techniques exist for each belt
    belts = syllabus.belts.to_a
    belts.each do |belt|
      2.times do
        tt = create(:technique_type, belt: belt, syllabus: syllabus)
        create_list(:technique, 2, technique_type: tt)
      end
    end

    user = create(:user)

    allow_any_instance_of(Api::V1::SyllabiController).to receive(:authenticate_api_v1_user!).and_return(true)
    allow_any_instance_of(Api::V1::SyllabiController).to receive(:current_api_v1_user).and_return(user)

    sql = []
    subscriber = ->(_name, _start, _finish, _id, payload) do
      sql << payload[:sql].to_s
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      get "/api/v1/syllabi/#{syllabus.id}/user_grade_syllabus", params: { use_jsonapi: '1' }
    end

    # Allow a single preload query using `IN (...)`, but disallow per-belt
    # equality queries like `WHERE technique_types.belt_id = $1` which indicate
    # an N+1. Only count queries that include an equality on `belt_id`.
    per_belt_eq = sql.select { |s| s =~ /technique_types.*belt_id\s*=/i }
    expect(per_belt_eq).to be_empty
  end
end
