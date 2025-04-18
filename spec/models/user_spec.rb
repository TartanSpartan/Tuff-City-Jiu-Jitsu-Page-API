require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'Factory' do
    it 'is valid' do
      user = FactoryBot.build(:user)
      expect(user).to be_valid
    end

    # Test the last_name attribute
    it 'generates a valid last_name' do
      user = FactoryBot.build(:user)
      expect(user.last_name).to match(/\A[\p{L}\p{M}\p{Pd}ʼ’‘\- ]+\z/)
    end

    # Test the email attribute
    it 'generates a valid email' do
      user = FactoryBot.build(:user)
      expect(user.email).to match(/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i)
    end

    # Test the admin user factory
    it 'creates an admin user' do
      admin_user = FactoryBot.build(:admin_user)
      expect(admin_user).to be_valid
      expect(admin_user.is_admin).to be_truthy
    end

    # Test to catch edge cases in random data generation
    it 'consistently generates valid users' do
      10.times do
        user = FactoryBot.build(:user)
        expect(user).to be_valid
      end
    end
  end

  # Will add other tests as more dependent models, controllers, serializers etc are reimplemented from the older version fo the project
end