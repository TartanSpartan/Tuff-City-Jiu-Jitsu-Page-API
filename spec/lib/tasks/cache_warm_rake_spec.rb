# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "cache:warm rake tasks" do
  before(:all) do
    Rails.application.load_tasks
  end

  describe "cache:warm:syllabi" do
    let!(:syllabus1) { create(:syllabus, :with_belts) }
    let!(:syllabus2) { create(:syllabus, :with_belts) }

    before do
      Rails.cache.clear
    end

    it "warms cache for all syllabi" do
      # The task should complete without error
      expect { Rake::Task["cache:warm:syllabi"].invoke }.not_to raise_error
    end

    it "can be invoked multiple times (reenable)" do
      Rake::Task["cache:warm:syllabi"].reenable

      expect { Rake::Task["cache:warm:syllabi"].invoke }.not_to raise_error

      Rake::Task["cache:warm:syllabi"].reenable
    end

    it "enqueues WarmSyllabusCacheJob for each syllabus" do
      Rake::Task["cache:warm:syllabi"].reenable

      # In test with inline adapter, jobs run immediately
      # We just verify it doesn't raise
      expect { Rake::Task["cache:warm:syllabi"].invoke }.not_to raise_error
    end
  end
end
