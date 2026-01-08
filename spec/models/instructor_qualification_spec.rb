# frozen_string_literal: true

require "rails_helper"

RSpec.describe InstructorQualification, type: :model do
  # --- Factory ---
  # These tests ensure that the FactoryBot factory is valid and creates records as expected.
  describe "Factory" do
    it "is a valid default factory" do
      expect(FactoryBot.build(:instructor_qualification)).to be_valid
    end

    it "is a valid factory with a belt grade" do
      expect(
        FactoryBot.build(:instructor_qualification, :with_belt_grade)
      ).to be_valid
    end
  end

  # --- Associations ---
  # We test the associations to make sure the model is correctly linked
  # to other models. This is a crucial part of model testing.
  describe "associations" do
    # `belongs_to :user` test
    it { should belong_to(:user).optional }
    # `belongs_to :belt_grade` test
    it { should belong_to(:belt_grade).optional }
    # `belongs_to :belt` test. This also implicitly tests the presence of a `belt`.
    it { should belong_to(:belt) }
    # `belongs_to :qualification` test. This also implicitly tests the presence of a `qualification`.
    it { should belong_to(:qualification) }
  end

  # --- Normalization & validation ---
  describe "normalization and validation" do
    it "normalizes qualification_id across syllabi into 1..4 via modulo" do
      # Raw id 6 -> effective 2 (since ((6-1) % 4)+1 = 2)
      belt = create(:belt)
      qual6 =
        Qualification.create!(id: 6, level: "Assistant instructor", belt: belt)
      uq = build(:instructor_qualification, qualification: qual6, belt: belt)
      expect(uq.valid?).to be true
      expect(uq.effective_qualification_id).to eq(2)
    end

    it "is invalid if effective_qualification_id is present and outside 1..4" do
      belt = create(:belt)
      uq = build(:instructor_qualification, belt: belt)
      # Remove qualification to avoid callback normalization and allow manual setting
      uq.qualification = nil
      # Stub the normalization callback so it does not overwrite our manual value
      allow(uq).to receive(:set_effective_qualification_id)
      uq.effective_qualification_id = 99
      expect(uq).to be_invalid
      expect(uq.errors[:effective_qualification_id]).to be_present
    end
  end

  describe "achieved_at conditional validation" do
    it 'requires achieved_at when qualification is not "No qualifications" (id != 1)' do
      belt = create(:belt)
      # Ensure id 2 exists (Assistant instructor)
      qual2 =
        Qualification.find_by(id: 2) ||
          Qualification.create!(
            id: 2,
            level: "Assistant instructor",
            belt: belt
          )
      iq =
        build(
          :instructor_qualification,
          qualification: qual2,
          belt: belt,
          achieved_at: nil
        )
      expect(iq).to be_invalid
      expect(iq.errors[:achieved_at].first).to match(
        /must not be blank|must not be blank|must not be blank/i
      )
    end

    it 'allows achieved_at to be nil when qualification is "No qualifications" (id == 1)' do
      belt = create(:belt)
      qual1 =
        Qualification.find_by(id: 1) ||
          Qualification.create!(id: 1, level: "No qualifications", belt: belt)
      iq =
        build(
          :instructor_qualification,
          qualification: qual1,
          belt: belt,
          achieved_at: nil
        )
      expect(iq).to be_valid
    end
  end

  describe "association optionality and requirements" do
    it "is valid without a user (optional: true)" do
      iq = build(:instructor_qualification, user: nil)
      expect(iq).to be_valid
    end

    it "is valid without a belt_grade (optional: true)" do
      iq = build(:instructor_qualification, belt_grade: nil)
      expect(iq).to be_valid
    end

    it "is invalid without a belt" do
      iq = build(:instructor_qualification, belt: nil)
      expect(iq).to be_invalid
      expect(iq.errors[:belt]).to be_present
    end

    it "is invalid without a qualification" do
      iq = build(:instructor_qualification, qualification: nil)
      expect(iq).to be_invalid
      expect(iq.errors[:qualification]).to be_present
    end
  end

  describe "recalculation on qualification change" do
    it "recomputes effective_qualification_id when qualification changes before validation" do
      belt = create(:belt)
      q2 =
        Qualification.find_by(id: 2) ||
          Qualification.create!(
            id: 2,
            level: "Assistant instructor",
            belt: belt
          )
      q3 =
        Qualification.find_by(id: 3) ||
          Qualification.create!(id: 3, level: "Instructor", belt: belt)
      iq = build(:instructor_qualification, belt: belt, qualification: q2)
      expect(iq.valid?).to be true
      expect(iq.effective_qualification_id).to eq(2)

      iq.qualification = q3
      expect(iq.valid?).to be true
      expect(iq.effective_qualification_id).to eq(3)
    end
  end

  describe "mapping examples" do
    it "maps ids 1..8 into 1..4 via modulo" do
      belt = create(:belt)
      cases = { 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 1, 6 => 2, 7 => 3, 8 => 4 }
      cases.each do |raw_id, expected|
        qual =
          Qualification.find_by(id: raw_id) ||
            Qualification.create!(
              id: raw_id,
              level: "Level #{raw_id}",
              belt: belt
            )
        iq = build(:instructor_qualification, qualification: qual, belt: belt)
        expect(iq.valid?).to be true
        expect(iq.effective_qualification_id).to eq(expected)
      end
    end
  end
end
