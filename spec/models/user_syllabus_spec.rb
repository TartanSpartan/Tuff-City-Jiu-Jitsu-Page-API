# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSyllabus, type: :model do
  # Test the associations to ensure the model connects to the right tables.
  describe 'associations' do
    it 'belongs to a user' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a syllabus' do
      association = described_class.reflect_on_association(:syllabus)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  # Test the validations to ensure data integrity.
  describe 'validations' do
    # Test that a user_syllabus can be created with valid attributes.
    it 'is valid with a unique user_id and syllabus_id combination' do
      user = create(:user)
      syllabus = create(:syllabus)
      user_syllabus = UserSyllabus.new(user:, syllabus:)
      expect(user_syllabus).to be_valid
    end

    # This is the key test for the unique index.
    it 'is invalid with a duplicate user_id and syllabus_id combination' do
      # Create fresh records for this test to ensure no state conflicts.
      user = create(:user)
      syllabus = create(:syllabus)

      # Create an initial user_syllabus record.
      UserSyllabus.create!(user:, syllabus:)
      # Try to create a second one with the exact same user and syllabus.
      duplicate = UserSyllabus.new(user:, syllabus:)

      expect(duplicate).to_not be_valid
      expect(duplicate.errors[:user_id]).to include('has already been taken for this syllabus')
    end

    # Test the presence validation for user and syllabus.
    it 'is invalid without a user' do
      syllabus = create(:syllabus)
      user_syllabus = UserSyllabus.new(user: nil, syllabus:)
      expect(user_syllabus).to_not be_valid
      expect(user_syllabus.errors[:user]).to include('must exist')
    end

    it 'is invalid without a syllabus' do
      user = create(:user)
      user_syllabus = UserSyllabus.new(user:, syllabus: nil)
      expect(user_syllabus).to_not be_valid
      expect(user_syllabus.errors[:syllabus]).to include('must exist')
    end
  end
end
