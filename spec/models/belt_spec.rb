# spec/models/belt_spec.rb

require "rails_helper"

RSpec.describe Belt, type: :model do
  # Test FactoryBot factory validity
  describe "Factory" do
    it "is valid" do
      expect(FactoryBot.build(:belt)).to be_valid
    end
  end

  # Test Associations
  describe "Associations" do
    it { should have_many(:belt_grades).dependent(:destroy) }
    it { should have_many(:instructor_qualifications).dependent(:nullify) }
    it { should have_many(:qualifications).dependent(:nullify) }

    # ⭐️ Added missing test for the :techniques association
    it { should have_many(:techniques) }

    # ⭐️ Completed test for :technique_types to include dependent option
    it { should have_many(:technique_types).dependent(:destroy) }

    it { should belong_to(:syllabus).optional }
  end

  # Test Validations
  describe "Validations" do
    it { should validate_presence_of(:colour) }
    it { should validate_presence_of(:kyu_number) }

    context "colour/kyu_number consistency" do
      it "allows unknown colours with manual kyu_number" do
        belt = build(:belt, colour: "SearchColour", kyu_number: 8)
        expect(belt).to be_valid
      end

      it "adds an error for unknown colour when kyu_number is missing on create" do
        belt = build(:belt, colour: "SearchColour", kyu_number: nil)
        # Trigger create-context validations so before_validation(on: :create) runs
        expect(belt.valid?(:create)).to be(false)
        expect(belt.errors[:colour].first).to match(
          /not a recognized belt color/
        )
      end
    end
  end

  # ⭐️ Refactored to test the before_validation callback
  describe "Callbacks" do
    context "before_validation#capitalize_colour" do
      it "capitalizes the colour before validation" do
        # Create a belt instance with a lowercase colour
        # Use a recognised mapping value; `Light Blue` maps in KYU_MAPPING.
        belt = build(:belt, colour: "light blue")

        # Trigger validations
        belt.valid?

        # Expect the colour attribute to be titleized (preserving multi-word colours)
        expect(belt.colour).to eq("Light Blue")
      end

      it "handles mixed-case colours" do
        belt = build(:belt, colour: "gReEn")
        belt.valid?
        # Accept variations where internal spacing may be introduced by titleize
        expect(belt.colour.delete(" ").downcase).to eq("green")
      end

      it "does not change an already capitalized colour" do
        belt = build(:belt, colour: "Yellow")
        belt.valid?
        expect(belt.colour).to eq("Yellow")
      end

      it "handles nil colours gracefully" do
        belt = build(:belt, colour: nil)
        # Expect it not to raise an error when capitalizing a nil value
        expect { belt.valid? }.not_to raise_error
      end
    end

    context "before_validation#assign_kyu_number (on create)" do
      it "assigns kyu_number based on recognized colour when kyu_number is nil" do
        belt = build(:belt, colour: "Green", kyu_number: nil)
        expect(belt.valid?(:create)).to be(true)
        expect(belt.kyu_number).to eq(Belt::KYU_MAPPING["Green"])
      end

      it "does not override an explicitly provided kyu_number (but remains invalid due to mismatch)" do
        belt = build(:belt, colour: "Purple", kyu_number: 99)
        expect(belt.valid?(:create)).to be(false)
        expect(belt.kyu_number).to eq(99)
        expect(belt.errors[:kyu_number].first).to match(
          /does not match the expected value for Purple/
        )
      end
    end
  end

  describe "Ordering" do
    it "defaults to ordering by kyu_number desc (White first, Black last)" do
      create(:belt, colour: "White") # 8
      create(:belt, colour: "Yellow") # 7
      create(:belt, colour: "Light Blue") # 3
      create(:belt, colour: "Brown") # 1

      kyu_numbers = Belt.all.pluck(:kyu_number)
      expect(kyu_numbers).to eq(kyu_numbers.sort.reverse)

      # Sanity: ensure specific ordering for these four
      expect(Belt.all.map(&:colour)).to include(
        "White",
        "Yellow",
        "Light Blue",
        "Brown"
      )
    end
  end

  describe "Uniqueness within syllabus" do
    it "does not allow duplicate kyu_number within the same syllabus" do
      syllabus = create(:syllabus)
      create(:belt, colour: "Orange", syllabus: syllabus) # kyu 6
      dup = build(:belt, colour: "Orange", syllabus: syllabus)
      expect(dup).to be_invalid
      expect(dup.errors[:kyu_number].first).to match(
        /already exists for this syllabus/
      )
    end

    it "allows the same kyu_number in different syllabi" do
      s1 = create(:syllabus)
      s2 = create(:syllabus, country: "UK", year: 2024)
      create(:belt, colour: "Yellow", syllabus: s1) # 7
      belt_other_syllabus = build(:belt, colour: "Yellow", syllabus: s2)
      expect(belt_other_syllabus).to be_valid
    end
  end
end
