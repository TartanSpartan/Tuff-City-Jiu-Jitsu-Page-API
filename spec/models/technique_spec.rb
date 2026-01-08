# spec/models/technique_spec.rb
require "rails_helper"

RSpec.describe Technique, type: :model do
  # Associations
  describe "associations" do
    it { should belong_to(:belt) }
    it { should belong_to(:technique_type) }

    # Test the new associations for differences.
    # The 'differences' association uses the default foreign key.
    it { should have_many(:differences).dependent(:destroy) }
    # The 'comparisons' association uses a custom foreign key.
    it do
      should have_many(:comparisons)
               .class_name("Difference")
               .with_foreign_key("compared_to_technique_id")
               .dependent(:destroy)
    end

    # Test the association for videos.
    it { should have_many(:videos).dependent(:destroy) }

    # Test that the videos association accepts nested attributes.
    it { should accept_nested_attributes_for(:videos).allow_destroy(true) }
  end

  # Validations
  describe "validations" do
    subject { build(:technique) }

    # This test is now manual for better reliability.
    it "validates the uniqueness of summary (case-insensitive)" do
      # Create an existing technique
      existing_technique = create(:technique, summary: "Unique Summary")

      # Build a new technique, ensuring it has all the necessary associations
      # to pass other validations.
      new_technique =
        build(
          :technique,
          summary: "unique summary",
          belt: existing_technique.belt,
          technique_type: existing_technique.technique_type
        )

      # Expect the new technique to be invalid
      expect(new_technique).not_to be_valid
      # Expect the error message to be present on the summary field
      expect(new_technique.errors[:summary]).to include(
        "has already been taken"
      )
    end

    it { should validate_presence_of(:summary) }
    it { should validate_length_of(:summary).is_at_least(5) }

    # Added tests for the presence of foreign keys.
    it { should validate_presence_of(:belt_id) }
    it { should validate_presence_of(:technique_type_id) }
  end

  # Callbacks
  describe "callbacks" do
    describe "before_validation :titleize_summary" do
      it "titleizes the summary before validation" do
        technique = build(:technique, summary: "this is a new technique")
        technique.valid?
        expect(technique.summary).to eq("This Is A New Technique")
      end

      it "trims and collapses whitespace before titleizing" do
        technique = build(:technique, summary: "  this   has   spaces  ")
        technique.valid?
        expect(technique.summary).to eq("This Has Spaces")
      end
    end
  end

  describe "nested attributes for videos" do
    it "creates videos when provided via videos_attributes on create" do
      belt = create(:belt)
      technique_type =
        create(:technique_type, syllabus: belt.syllabus, belt: belt)

      attrs =
        attributes_for(:technique).merge(
          belt_id: belt.id,
          technique_type_id: technique_type.id,
          videos_attributes: [
            { url: "https://youtu.be/dQw4w9WgXcQ", country: "X", year: 2020 },
            { url: "https://youtu.be/3JZ_D3ELwOQ", country: "Y", year: 2021 }
          ]
        )

      tech = Technique.create(attrs)
      expect(tech).to be_persisted
      expect(tech.videos.count).to eq 2
      # The Video model normalizes YouTube URLs to the canonical
      # `https://www.youtube.com/watch?v=VIDEO_ID` form during
      # `before_validation :normalize_url` so assert against the
      # normalized form instead of the original input.
      expect(tech.videos.pluck(:url)).to include(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      )
    end

    it "allows destroying nested videos via _destroy flag" do
      tech = create(:technique, :with_videos, videos_count: 1)
      v = tech.videos.first

      update_attrs = { videos_attributes: [{ id: v.id, _destroy: "1" }] }

      tech.update(update_attrs)
      tech.reload
      expect(tech.videos.count).to eq 0
    end
  end
end
