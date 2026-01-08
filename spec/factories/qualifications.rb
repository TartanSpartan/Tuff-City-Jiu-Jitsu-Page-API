FactoryBot.define do
  factory :qualification do
    belt

    # The `level`is the only attribute that varies in our records.
    # We can use a sequence to create unique levels for each record,
    # or we can use the traits below for specific ones. 
    sequence(:level) do |n|
      levels = [ "No qualifications", "Assistant instructor", "Instructor", "Club instructor" ]
      levels[n % levels.length]
    end

    # The `belt_id` is always `nil` in our sample data, so we don't
    # need to include an association or a trait for it here.

    # Traits for creating specific qualification types for our tests.
    trait :no_qualification do
      level { "No qualifications" }
    end

    trait :assistant_instructor do
      level { "Assistant instructor" }
    end

    trait :instructor do
      level { "Instructor" }
    end

    trait :club_instructor do
      level { "Club instructor" }
    end
  end
end
