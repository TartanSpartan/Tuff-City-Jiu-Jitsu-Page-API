require "rails_helper"

RSpec.describe Difference, type: :model do
  # Use FactoryBot to create a valid instance of the model for testing.
  let(:difference) { FactoryBot.create(:difference) }

  # Test for associations
  describe "associations" do
    it "belongs to a technique" do
      # Checks if the model has a belongs_to association with Technique.
      association = described_class.reflect_on_association(:technique)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to a compared_to_technique" do
      # Checks for the second belongs_to association, with the correct class name.
      association =
        described_class.reflect_on_association(:compared_to_technique)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq("Technique")
    end
  end

  # Test for validations
  describe "validations" do
    it "is valid with valid attributes" do
      # Ensures that a difference with a content and associated techniques is valid.
      expect(difference).to be_valid
    end

    it "is not valid without content" do
      # Sets the content to nil and checks if the model is invalid.
      difference.content = nil
      expect(difference).to_not be_valid
    end

    # A more robust test to ensure that the foreign keys are required.
    it "is not valid without an associated technique" do
      difference.technique = nil
      expect(difference).to_not be_valid
    end

    it "is not valid without a compared_to_technique" do
      difference.compared_to_technique = nil
      expect(difference).to_not be_valid
    end

    # Tests the custom validation to prevent a technique from being compared to itself.
    it "is not valid if a technique is compared to itself" do
      same_technique = create(:technique)
      duplicate_difference =
        build(
          :difference,
          technique: same_technique,
          compared_to_technique: same_technique
        )
      expect(duplicate_difference).to_not be_valid
      expect(duplicate_difference.errors[:base]).to include(
        "A technique cannot be compared to itself"
      )
    end
  end

  describe "cross-syllabus comparisons" do
    it "allows differences between techniques in different syllabi" do
      ca_syllabus = create(:syllabus, country: "CA", year: 2024)
      uk_syllabus = create(:syllabus, country: "UK", year: 2024)

      ca_belt = create(:belt, colour: "Light Blue", syllabus: ca_syllabus)
      uk_belt = create(:belt, colour: "Green", syllabus: uk_syllabus)

      ca_type = create(:technique_type, syllabus: ca_syllabus, belt: ca_belt)
      uk_type = create(:technique_type, syllabus: uk_syllabus, belt: uk_belt)

      t1 = create(:technique, belt: ca_belt, technique_type: ca_type)
      t2 = create(:technique, belt: uk_belt, technique_type: uk_type)

      diff = build(:difference, technique: t1, compared_to_technique: t2)
      expect(diff).to be_valid
    end
  end

  describe "dependent destruction from Technique" do
    it "destroys a difference when the base technique is destroyed" do
      t1 = create(:technique)
      t2 = create(:technique)
      diff = create(:difference, technique: t1, compared_to_technique: t2)
      expect { t1.destroy }.to change {
        Difference.where(id: diff.id).exists?
      }.from(true).to(false)
    end

    it "destroys a difference when the compared_to_technique is destroyed" do
      t1 = create(:technique)
      t2 = create(:technique)
      diff = create(:difference, technique: t1, compared_to_technique: t2)
      expect { t2.destroy }.to change {
        Difference.where(id: diff.id).exists?
      }.from(true).to(false)
    end
  end

  describe "duplicates" do
    it "currently allows duplicate pairs (directional)" do
      t1 = create(:technique)
      t2 = create(:technique)
      create(:difference, technique: t1, compared_to_technique: t2)
      dup = build(:difference, technique: t1, compared_to_technique: t2)
      expect(dup).to be_valid
    end
  end
end
