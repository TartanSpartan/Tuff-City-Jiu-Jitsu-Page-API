require "rails_helper"

RSpec.describe Qualification, type: :model do
  # --- Factory ---
  # This test ensures that the default factory is valid and creates records as expected.
  describe "Factory" do
    it "is a valid default factory" do
      expect(FactoryBot.build(:qualification)).to be_valid
    end
  end

  # --- Associations ---
  # These tests verify that the model's associations are correctly defined.
  describe "associations" do
    it { should have_one(:instructor_qualification) }
    it { should belong_to(:belt) }
  end

  # --- Callbacks ---
  # These tests cover the custom logic defined in the model's callbacks.
  describe "callbacks" do
    describe "before_save :capitalize_level" do
      it "capitalizes the level before saving" do
        qualification = create(:qualification, level: "black belt")
        expect(qualification.level).to eq("Black belt")
      end

      it "does not error if level is already capitalized" do
        qualification = create(:qualification, level: "Instructor")
        expect(qualification.level).to eq("Instructor")
      end

      it "capitalizes only the first letter for multi-word levels" do
        qualification = create(:qualification, level: "assistant instructor")
        expect(qualification.level).to eq("Assistant instructor")
      end

      it "handles empty string level gracefully" do
        qualification = create(:qualification, level: "")
        expect(qualification.level).to eq("")
      end

      it "handles nil level gracefully (does not raise)" do
        qualification = build(:qualification, level: nil)
        expect { qualification.save }.not_to raise_error
        expect(qualification.level).to be_nil
      end
    end
  end

  # --- Cross-model behavior ---
  describe "cross-model behavior" do
    it "can be associated with an InstructorQualification" do
      qualification = create(:qualification)
      instructor_qualification =
        create(
          :instructor_qualification,
          qualification: qualification,
          belt: qualification.belt
        )
      expect(instructor_qualification.qualification).to eq(qualification)
      expect(qualification.instructor_qualification).to eq(
        instructor_qualification
      )
    end

    it "is always associated with a Belt" do
      qualification = create(:qualification)
      expect(qualification.belt).to be_a(Belt)
    end
  end
end
