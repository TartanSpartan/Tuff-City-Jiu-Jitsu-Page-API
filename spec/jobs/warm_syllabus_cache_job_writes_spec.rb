require 'rails_helper'

RSpec.describe WarmSyllabusCacheJob, type: :job do
  it 'writes belt/technique_type/technique fragments into the cache' do
    syllabus = create(:syllabus, :with_belts)
    belts = syllabus.belts.to_a
    tt_list = []
    belts.each do |belt|
      2.times do
        tt = create(:technique_type, belt: belt, syllabus: syllabus)
        tt_list << tt
        create_list(:technique, 2, technique_type: tt)
      end
    end

    # Use a memory store for this test so fragments persist
    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    # Warm the cache synchronously
    WarmSyllabusCacheJob.perform_now(syllabus.id, nil)

    # Check that the memory store contains at least one syllabus fragment
    data = Rails.cache.instance_variable_get(:@data)
    keys = data.respond_to?(:keys) ? data.keys.map(&:to_s) : []
    expect(keys.any? { |k| k.start_with?("syllabus/#{syllabus.id}/") }).to be_truthy
  ensure
    Rails.cache = old_cache
  end
end
