FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name.gsub(/[^\p{L}\p{M}\p{Pd}ʼ’‘\- ]/, "") } # Example to sanitize last name
    email { Faker::Internet.unique.email }
    password { "password123" }
    password_confirmation { "password123" }

    # Prevent syllabus auto-creation unless explicitly needed, to avoid infinite loops
    transient do
      create_syllabus { false }
      # Add a transient attribute for qualification level
      qualification_level { nil }
    end

    # Default to non-admin
    is_admin { false }
    # Default GI ownership to true to avoid colored-belt grading validations in tests
    owns_gi { true }

    # Using `after(:create)` to conditionally create associations is a great pattern.
    after(:create) do |user, evaluator|
      create(:syllabus, user: user) if evaluator.create_syllabus

      # We can now use the transient attribute to create a qualification
      if evaluator.qualification_level
        create(
          :instructor_qualification,
          user: user,
          qualification:
            create(:qualification, level: evaluator.qualification_level)
        )
      end
    end

    trait :with_waiver do
      after(:create) { |user| create(:waiver, user: user) }
    end

    # factory :admin_user, parent: :user do # Inherit from the base user factory
    #   is_admin { true } # Override is_admin to true for admin users
    # end

    trait :admin do
      is_admin { true }
    end

    # Traits for creating a user with a specific qualification,
    # which ties back to the factories we've built.
    trait :with_no_qualification do
      qualification_level { "No qualifications" }
    end

    trait :with_assistant_instructor_qual do
      qualification_level { "Assistant instructor" }
    end

    trait :with_club_instructor_qual do
      qualification_level { "Club instructor" }
    end
  end
end
