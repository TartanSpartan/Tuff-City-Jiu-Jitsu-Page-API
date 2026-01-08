require "rails_helper"

RSpec.describe Syllabus, type: :model do
  # --- Custom Validations: Admin Flags ---
  describe "admin flag validations" do
    it "does not allow more than one primary admin syllabus" do
      create(:syllabus, is_primary_admin_syllabus: true)
      another = build(:syllabus, is_primary_admin_syllabus: true)
      expect(another).not_to be_valid
      expect(another.errors[:is_primary_admin_syllabus]).to include(
        "can only be set on one syllabus at a time."
      )
    end

    it "does not allow more than one secondary admin syllabus" do
      create(:syllabus, is_secondary_admin_syllabus: true)
      another = build(:syllabus, is_secondary_admin_syllabus: true)
      expect(another).not_to be_valid
      expect(another.errors[:is_secondary_admin_syllabus]).to include(
        "can only be set on one syllabus at a time."
      )
    end

    it "does not allow a syllabus to be both primary and secondary admin" do
      syllabus =
        build(
          :syllabus,
          is_primary_admin_syllabus: true,
          is_secondary_admin_syllabus: true
        )
      expect(syllabus).not_to be_valid
      expect(syllabus.errors[:base]).to include(
        "A syllabus cannot be set as both primary and secondary."
      )
    end
  end

  # --- Scopes ---
  describe "scopes" do
    it ".primary_admin returns only primary admin syllabi" do
      primary = create(:syllabus, is_primary_admin_syllabus: true)
      non_primary = create(:syllabus, is_primary_admin_syllabus: false)
      expect(Syllabus.primary_admin).to include(primary)
      expect(Syllabus.primary_admin).not_to include(non_primary)
    end

    it ".secondary_admin returns only secondary admin syllabi" do
      secondary = create(:syllabus, is_secondary_admin_syllabus: true)
      non_secondary = create(:syllabus, is_secondary_admin_syllabus: false)
      expect(Syllabus.secondary_admin).to include(secondary)
      expect(Syllabus.secondary_admin).not_to include(non_secondary)
    end
  end
  # A basic factory is enough for most of these tests.
  let(:syllabus) { create(:syllabus) }

  # --- Associations ---
  describe "associations" do
    it "has many user syllabi" do
      expect(Syllabus.reflect_on_association(:user_syllabi).macro).to eq(
        :has_many
      )
    end

    it "has many users through user syllabi" do
      expect(Syllabus.reflect_on_association(:users).macro).to eq(:has_many)
      expect(Syllabus.reflect_on_association(:users).options[:through]).to eq(
        :user_syllabi
      )
    end

    it "has many belts" do
      expect(Syllabus.reflect_on_association(:belts).macro).to eq(:has_many)
    end

    it "has many technique types" do
      expect(Syllabus.reflect_on_association(:technique_types).macro).to eq(
        :has_many
      )
    end
  end

  # --- Validations ---
  describe "validations" do
    it "is valid with a country and year" do
      expect(build(:syllabus, country: "NZ", year: 2024)).to be_valid
    end

    it "is not valid without a country" do
      expect(build(:syllabus, country: nil)).to_not be_valid
    end

    it "is not valid without a year" do
      expect(build(:syllabus, year: nil)).to_not be_valid
    end

    it "is not valid with a non-integer year" do
      expect(build(:syllabus, year: 2024.5)).to_not be_valid
    end

    it "is not valid if the country and year combination is not unique" do
      create(:syllabus, country: "NZ", year: 2024)
      syllabus = build(:syllabus, country: "NZ", year: 2024)
      expect(syllabus).to_not be_valid
    end
  end

  # --- Dependent Destruction ---
  describe "dependent destruction" do
    let!(:syllabus_with_dependents) do
      create(
        :syllabus,
        :with_belts,
        country: "UniqueCountry_#{SecureRandom.hex(4)}",
        year: 2024 + rand(1000)
      )
    end

    it "destroys associated belts when the syllabus is destroyed" do
      # The :with_belts trait creates one belt per unique kyu_number in Belt::KYU_MAPPING
      expect { syllabus_with_dependents.destroy }.to change(Belt, :count).by(
        -Belt::KYU_MAPPING.size
      )
    end

    it "destroys associated technique types when the syllabus is destroyed" do
      # Note: The :with_belts trait creates a number of technique types equal to the number of categories.
      # The number of technique types is 9 based on our factory.
      expect { syllabus_with_dependents.destroy }.to change(
        TechniqueType,
        :count
      ).by(-9)
    end

    it "destroys associated user syllabi when the syllabus is destroyed" do
      # The factory does not automatically create user syllabi. We need to create one for this test.
      user = create(:user)
      create(:user_syllabus, user: user, syllabus: syllabus_with_dependents)
      expect { syllabus_with_dependents.destroy }.to change(
        UserSyllabus,
        :count
      ).by(-1)
    end
  end
end
