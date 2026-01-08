FactoryBot.define do
  factory :instructor_qualification do
    # This association tells FactoryBot to create a user record automatically.
    # The `user` object passed in the test will override this default.
    association :user
    # This factory no longer creates a BeltGrade by default, as that can lead to circular dependencies.
    # Use the `with_belt_grade` trait when a BeltGrade association is needed.
    association :belt

    # Use a sequence for the Qualification to ensure uniqueness, even if the model doesn't require it.
    # This is a good practice to prevent future issues.
    association :qualification, factory: :qualification_with_sequence

    # Default achieved_at so the factory is valid out of the box
    achieved_at { Faker::Date.backward(days: 365) }

    # Ensure base Qualifications (IDs 1..4) exist to satisfy the foreign key on effective_qualification_id
    before(:create) do |_iq|
      # Create or find a safe default belt for base qualifications
      white_belt = Belt.find_or_create_by(colour: "White", syllabus_id: nil)

      # Normalize base qualification records expected by the model's effective_qualification_id (1..4)
      base_levels = [
        "No qualifications",
        "Assistant instructor",
        "Instructor",
        "Club instructor"
      ]

      base_levels.each_with_index do |level, idx|
        target_id = idx + 1
        Qualification.find_by(id: target_id) ||
          Qualification.create(id: target_id, level: level, belt: white_belt)
      end
    end

    # Trait for explicit control when tests need to override
    trait :achieved do
      achieved_at { Faker::Date.backward(days: 180) }
    end

    # Explicitly associate a belt grade with this factory when needed in tests.
    trait :with_belt_grade do
      association :belt_grade
    end

    trait :no_belt_grade do
      belt_grade { nil }
    end

    # Example trait for creating a specific type of qualification, like a "Club Instructor".
    trait :as_club_instructor do
      qualification do
        association(:qualification_with_sequence, level: "Club instructor")
      end
    end

    # Another example for an "Assistant Instructor" qualification.
    trait :as_assistant_instructor do
      qualification do
        association(:qualification_with_sequence, level: "Assistant instructor")
      end
    end
  end

  # We create a new factory for Qualification with a sequence to prevent any potential uniqueness conflicts
  # in other parts of our test suite.
  factory :qualification_with_sequence, class: "Qualification" do
    sequence(:level) { |n| "Qualification Level #{n}" }

    # The Qualification model requires a belt to exist.
    # This line ensures that a valid belt is created for this association.
    association :belt
  end
end
