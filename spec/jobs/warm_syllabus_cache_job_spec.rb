require 'rails_helper'

RSpec.describe WarmSyllabusCacheJob, type: :job do
  it 'warms without running per-belt technique_type queries' do
    syllabus = create(:syllabus, :with_belts)

    # Ensure each belt has some technique_types and techniques
    Belt.where(syllabus: syllabus).each do |belt|
      create_list(:technique_type, 2, :with_techniques, syllabus: syllabus, belt: belt)
    end

    sql = []
    subscriber = lambda do |*args|
      payload = args.last
      text = payload[:sql]
      # Ignore transactional/schema noise
      unless text =~ /\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK|PRAGMA|SELECT currval|SHOW search_path)/i
        sql << text
      end
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      WarmSyllabusCacheJob.perform_now(syllabus.id)
    end

    per_belt_queries = sql.select { |s| s =~ /WHERE .*technique_types.*belt_id|WHERE .*"technique_types".*"belt_id"/i }

    expect(per_belt_queries).to be_empty, "Expected no per-belt technique_type queries, found:\n#{per_belt_queries.join("\n")}" 
  end
end
# frozen_string_literal: true

require "rails_helper"

RSpec.describe WarmSyllabusCacheJob, type: :job do
  include ActiveJob::TestHelper

  let!(:syllabus) { create(:syllabus, :with_belts) }
  let!(:user) { create(:user) }

  # Use a memory cache for these tests and set the ActiveJob adapter to :test
  around do |example|
    original_cache = Rails.cache
    original_adapter = ActiveJob::Base.queue_adapter
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActiveJob::Base.queue_adapter = :test
    example.run
    Rails.cache = original_cache
    ActiveJob::Base.queue_adapter = original_adapter
  end
  describe "#perform" do
    it "writes the syllabus payload to the cache" do
      # Ensure cache is clear
      Rails.cache.clear

      # Perform the job
      described_class.perform_now(syllabus.id)

      # The job should have written something to cache
      # We check by fetching the same key pattern the job uses
      user_kyu = 8 # default when no user provided
      belts = syllabus.visible_belts_for(nil)
      last_belt_ts = belts.maximum(:updated_at)&.to_i
      last_tt_ts = TechniqueType.where(syllabus_id: syllabus.id).maximum(:updated_at)&.to_i
      last_tech_ts = Technique.joins(:technique_type).where(technique_types: { syllabus_id: syllabus.id }).maximum(:updated_at)&.to_i

      cache_key = [
        'syllabus',
        syllabus.id,
        'user_grade',
        user_kyu,
        syllabus.updated_at.to_i,
        last_belt_ts,
        last_tt_ts,
        last_tech_ts
      ].join('/')

      cached = Rails.cache.read(cache_key)
      expect(cached).to be_present
      expect(cached[:data][:type]).to eq("syllabi")
      expect(cached[:data][:id]).to eq(syllabus.id.to_s)
    end

    it "builds the correct JSON:API payload structure" do
      Rails.cache.clear
      payload = described_class.perform_now(syllabus.id)

      expect(payload).to have_key(:data)
      expect(payload).to have_key(:included)
      expect(payload[:data][:type]).to eq("syllabi")
      expect(payload[:data][:attributes]).to have_key(:country)
      expect(payload[:data][:attributes]).to have_key(:year)
      expect(payload[:data][:relationships]).to have_key(:belts)
    end

    it "warms cache for a specific user's view when user_id is provided" do
      Rails.cache.clear

      # Give the user a belt grade so their view differs
      orange_belt = syllabus.belts.find_by(kyu_number: 6)
      create(:belt_grade, user: user, belt: orange_belt, obtained_at: Date.current) if orange_belt

      payload = described_class.perform_now(syllabus.id, user.id)

      # The user's kyu should be 6 (Orange), so cache key differs
      expect(payload).to be_present
      expect(payload[:data][:id]).to eq(syllabus.id.to_s)
    end

    it "returns nil and does not raise when syllabus does not exist" do
      result = described_class.perform_now(999_999)
      expect(result).to be_nil
    end

    it "includes belt resources in the payload" do
      Rails.cache.clear
      payload = described_class.perform_now(syllabus.id)

      belt_resources = payload[:included].select { |r| r[:type] == "belts" }
      expect(belt_resources).not_to be_empty

      # Each belt resource should have expected attributes
      first_belt = belt_resources.first
      expect(first_belt[:attributes]).to have_key(:colour)
      expect(first_belt[:attributes]).to have_key(:kyu_number)
      expect(first_belt[:attributes]).to have_key(:effective_kyu_grade)
    end
  end

  describe "job queuing" do
    it "is enqueued in the default queue" do
      expect {
        described_class.perform_later(syllabus.id)
      }.to have_enqueued_job(described_class).on_queue("default")
    end

    it "can be performed later with syllabus_id and user_id" do
      expect {
        described_class.perform_later(syllabus.id, user.id)
      }.to have_enqueued_job(described_class).with(syllabus.id, user.id)
    end
  end
end
