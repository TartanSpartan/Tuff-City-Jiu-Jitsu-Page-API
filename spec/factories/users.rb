FactoryBot.define do
    factory :user do
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name.gsub(/[^\p{L}\p{M}\p{Pd}ʼ’‘\- ]/, '') } # Example to sanitize last name
      email { Faker::Internet.unique.email }
      password { "password123" }
      password_confirmation { "password123" }
  
      # Prevent syllabus auto-creation unless explicitly needed, to avoid infinite loops
      transient do
        create_syllabus { false }
      end
  
      # Default to non-admin
      is_admin { false }
  
      # after(:create) do |user, evaluator|
      #   create(:syllabus, user: user) if evaluator.create_syllabus
      # end
  
      trait :with_waiver do
        after(:create) { |user| create(:waiver, user: user) }   
      end
      
      factory :admin_user, parent: :user do # Inherit from the base user factory
        is_admin { true } # Override is_admin to true for admin users
      end
    end
  end