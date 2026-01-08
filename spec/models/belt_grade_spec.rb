require "rails_helper"
#
# BeltGrade model test rubric (maintainers' guide)
#
# Effective kyu mapping and normalization:
# - effective_kyu_grade is normalized into the range 1..8 from belt.kyu_number.
# - Current domain convention used by this spec: 1 = Brown (highest kyu), 8 = White (lowest kyu).
# - grade_name prefers belt.colour when present; otherwise falls back to the effective kyu → colour mapping.
#
# Callback behavior:
# - effective_kyu_grade is recalculated before validation when belt_id changes
#   (via will_save_change_to_belt_id?).
#
# Domain rules covered:
# - GI required to grade: required for coloured belts and above (effective kyu <= 7), not required for White (8).
# - Instructor qualification thresholds:
#   * Purple (4th kyu) and Light Blue (3rd kyu) → Assistant Instructor (qualification_id >= 2)
#   * Dark Blue (2nd kyu) → Instructor (qualification_id >= 3)
#   * Brown (1st kyu) → Club Instructor (qualification_id >= 4)
# - First-aid requirement: Brown (1st kyu) requires has_first_aid_qualification = true
#   with a recorded first_aid_achievement_date.
#
# Testing notes:
# - Some tests set explicit kyu_number on belts to decouple expectations from
#   Belt::KYU_MAPPING colour ↔ kyu mapping.
# - belt_label is a private method and is invoked via `send(:belt_label)`.
# The `BeltGrade` model spec ensures that the model behaves as expected,
# including its associations, validations, and custom methods like `time_held`.
RSpec.describe BeltGrade, type: :model do
  # Use ActiveSupport's `TimeHelpers` to control the date for testing
  # the `time_held` method.
  include ActiveSupport::Testing::TimeHelpers

  # --- Associations ---
  # These tests verify that the model's associations are correctly defined.
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:belt) }
    it { should have_one(:instructor_qualification).dependent(:nullify) }
  end

  # --- Validations ---
  # These tests ensure that the model's validations are correctly enforced.
  describe "validations" do
    # Test for the presence of the `obtained_at` timestamp.
    it { should validate_presence_of(:obtained_at) }

    # Test that the `user` association is required.
    it "is invalid without a user" do
      belt_grade = build(:belt_grade, user: nil)
      expect(belt_grade).to be_invalid
      expect(belt_grade.errors[:user]).to include("must exist")
    end
  end

  # --- Instance Methods ---
  # These tests cover the custom logic defined in the `BeltGrade` model.
  describe "#time_held" do
    # Freeze time to a consistent date for predictable test results.
    let(:start_date) { Date.new(2024, 9, 1) }

    context "when the belt grade has been held for less than a month" do
      it 'returns "Less than a month"' do
        travel_to start_date + 10.days do
          belt_grade = build(:belt_grade, obtained_at: start_date)
          expect(belt_grade.time_held).to eq("Less than a month")
        end
      end
    end

    context "when the belt grade has been held for one month" do
      it 'returns "1 month"' do
        travel_to start_date + 30.days do
          belt_grade = build(:belt_grade, obtained_at: start_date)
          expect(belt_grade.time_held).to eq("1 month")
        end
      end
    end

    context "when the belt grade has been held for multiple months" do
      it "returns the correct number of months" do
        travel_to start_date + 65.days do
          belt_grade = build(:belt_grade, obtained_at: start_date)
          expect(belt_grade.time_held).to eq("2 months")
        end
      end
    end

    context "when the belt grade has been held for one year" do
      it 'returns "1 year and 0 months"' do
        travel_to start_date + 365.days do
          belt_grade = build(:belt_grade, obtained_at: start_date)
          expect(belt_grade.time_held).to eq("1 year and 0 months")
        end
      end
    end

    context "when the belt grade has been held for multiple years and months" do
      it "returns the correct number of years and months" do
        travel_to start_date + 800.days do
          belt_grade = build(:belt_grade, obtained_at: start_date)
          expect(belt_grade.time_held).to eq("2 years and 2 months")
        end
      end
    end
  end

  # --- Derived fields and domain rules ---
  describe "effective_kyu_grade recalculation" do
    it "sets effective_kyu_grade from belt kyu on create" do
      belt = create(:belt, colour: "White") # kyu_number 8
      user = create(:user)
      bg = build(:belt_grade, belt: belt, user: user)
      expect { bg.valid? }.to change { bg.effective_kyu_grade }.from(nil).to(8)
    end

    it "recomputes effective_kyu_grade when belt_id changes" do
      user = create(:user)
      bg = create(:belt_grade, belt: create(:belt, colour: "White"), user: user) # effective 8
      expect(bg.effective_kyu_grade).to eq(8)

      bg.belt = create(:belt, colour: "Yellow") # kyu_number 7
      bg.save!
      expect(bg.effective_kyu_grade).to eq(7)
    end
  end

  describe "#grade_name" do
    it "returns the belt colour when present" do
      # Provide an explicit kyu_number for a custom colour to satisfy model validation
      belt = create(:belt, colour: "Custom", kyu_number: 5)
      bg = build(:belt_grade, belt: belt)
      bg.valid? # trigger callback to set effective_kyu_grade
      expect(bg.grade_name).to eq("Custom")
    end

    it "falls back to effective kyu mapping when belt colour is absent" do
      # Use a known kyu where mapping is aligned (Yellow = 7, White = 8)
      yellow_belt = create(:belt, colour: "Yellow")
      bg_yellow = build(:belt_grade, belt: yellow_belt)
      bg_yellow.valid?
      expect(bg_yellow.grade_name).to eq("Yellow")

      white_belt = create(:belt, colour: "White")
      bg_white = build(:belt_grade, belt: white_belt)
      bg_white.valid?
      expect(bg_white.grade_name).to eq("White")
    end
  end

  describe "numericality for effective_kyu_grade" do
    it "allows nil without adding numericality errors (even if other validations fail)" do
      bg = build(:belt_grade)
      # Clear belt so callback leaves effective_kyu_grade nil; belt presence will fail
      bg.belt = nil
      expect(bg).to be_invalid
      expect(bg.effective_kyu_grade).to be_nil
      expect(bg.errors[:effective_kyu_grade]).to be_empty
      expect(bg.errors[:belt]).to include("must exist")
    end

    it "is invalid when outside the 1..8 range" do
      bg = build(:belt_grade)
      bg.effective_kyu_grade = 0
      expect(bg).to be_invalid
      expect(bg.errors[:effective_kyu_grade]).to be_present

      bg.effective_kyu_grade = 9
      expect(bg).to be_invalid
      expect(bg.errors[:effective_kyu_grade]).to be_present
    end
  end

  describe "GI requirement rule" do
    it "requires GI ownership for Yellow and above (<= 7)" do
      # Yellow belt (7) with user who does not own a GI should be invalid
      user_no_gi = create(:user, owns_gi: false)
      bg =
        build(
          :belt_grade,
          belt: create(:belt, colour: "Yellow"),
          user: user_no_gi
        )
      expect(bg).to be_invalid
      expect(bg.errors[:belt_id]).to include(/must own a gi/i)
      expect(bg.errors[:base]).to include(/GI ownership is mandatory/i)
    end

    it "does not require GI for White (8)" do
      user_no_gi = create(:user, owns_gi: false)
      bg =
        build(
          :belt_grade,
          belt: create(:belt, colour: "White"),
          user: user_no_gi
        )
      expect(bg).to be_valid
    end

    it "passes when user owns a GI" do
      user_with_gi = create(:user, owns_gi: true)
      bg =
        build(
          :belt_grade,
          belt: create(:belt, colour: "Yellow"),
          user: user_with_gi
        )
      expect(bg).to be_valid
    end
  end

  describe "effective kyu normalization" do
    # Assert the modulo-based normalization keeps effective_kyu_grade in 1..8
    it "normalizes raw kyu values into 1..8" do
      user = create(:user)
      cases = [[8, 8], [1, 1], [0, 8], [9, 1], [16, 8], [-1, 7], [-8, 8]]
      cases.each do |raw, expected|
        belt = create(:belt, kyu_number: raw, colour: "Custom")
        bg = build(:belt_grade, belt: belt, user: user)
        bg.valid?
        expect(bg.effective_kyu_grade).to eq(expected)
      end
    end
  end

  shared_examples "requires minimum qualification" do |kyu:, min_id:, expected_text:|
    it "enforces qualification id >= #{min_id} for kyu #{kyu}" do
      user = create(:user, owns_gi: true)
      belt = create(:belt, kyu_number: kyu, colour: "Custom")
      bg = build(:belt_grade, belt: belt, user: user)
      expect(bg).to be_invalid
      expect(bg.errors[:belt_id]).to include(expected_text)

      level =
        case min_id
        when 2
          "Assistant instructor"
        when 3
          "Instructor"
        when 4
          "Club instructor"
        else
          "Qualification Level"
        end
      qual =
        Qualification.find_or_create_by(
          id: min_id,
          level: level,
          belt: create(:belt, colour: "White")
        )
      create(:instructor_qualification, user: user, qualification: qual)
      bg2 = build(:belt_grade, belt: belt, user: user)
      expect(bg2).to be_valid
    end
  end

  describe "instructor qualification rules (shared examples)" do
    # Note: We set explicit kyu_number values on belts in these tests to decouple
    # expectations from Belt::KYU_MAPPING colour ↔ kyu mapping. This keeps tests
    # deterministic even if mapping or colour names evolve.
    include_examples "requires minimum qualification",
                     kyu: 4,
                     min_id: 2,
                     expected_text: /Assistant Instructor qualification/i
    include_examples "requires minimum qualification",
                     kyu: 3,
                     min_id: 2,
                     expected_text: /Assistant Instructor qualification/i
    include_examples "requires minimum qualification",
                     kyu: 2,
                     min_id: 3,
                     expected_text: /Instructor qualification/i
    # Brown (kyu 1) retains a dedicated test due to the first-aid dependency
  end

  # Note: Brown (kyu 1) qualification rule is covered alongside first-aid dependency in
  # the dedicated contexts below. The shared examples above cover kyu 4, 3, and 2.

  describe "first aid requirement for Brown (1st kyu)" do
    # Similar to the qualification rules, we use explicit kyu_number to ensure we
    # target effective kyu 1 precisely, independent of colour mapping changes.
    it "requires has_first_aid_qualification = true when effective kyu is 1" do
      user = create(:user, owns_gi: true, has_first_aid_qualification: false)
      belt_effective_1 = create(:belt, kyu_number: 1, colour: "Brown")
      bg = build(:belt_grade, belt: belt_effective_1, user: user)
      expect(bg).to be_invalid
      expect(bg.errors[:belt_id]).to include(/First Aid and CPR qualification/i)
    end

    it "passes when user has first aid qualification (with achievement date set) and required club instructor qualification" do
      user =
        create(
          :user,
          owns_gi: true,
          has_first_aid_qualification: true,
          first_aid_achievement_date: Date.current - 1.year
        )
      # Satisfy club instructor rule so we isolate the first-aid check
      club_instructor =
        Qualification.find_or_create_by(
          id: 4,
          level: "Club instructor",
          belt: create(:belt, colour: "White")
        )
      create(
        :instructor_qualification,
        user: user,
        qualification: club_instructor
      )
      belt_effective_1 = create(:belt, kyu_number: 1, colour: "Brown")
      bg = build(:belt_grade, belt: belt_effective_1, user: user)
      expect(bg).to be_valid
    end
  end

  describe "#belt_label" do
    # belt_label is a private method; we call it via `send` to assert formatting
    # without altering the visibility in the model.
    it "formats label with colour and ordinalized kyu" do
      belt = create(:belt, kyu_number: 4, colour: "Purple")
      bg = build(:belt_grade, belt: belt)
      bg.valid?
      expect(bg.send(:belt_label)).to match(/Purple Belt \(4th kyu\)/)
    end

    it "falls back to generic when belt is missing" do
      bg = build(:belt_grade, belt: nil)
      expect(bg.send(:belt_label)).to eq("the selected Belt")
    end
  end
end
