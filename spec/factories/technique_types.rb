FactoryBot.define do
  factory :technique_type do
    # Generate realistic, dynamic data using Faker
    category { Faker::Lorem.word }
    # sub_category is optional; provide only when a test needs an explicit value
    transient { with_sub_category { false } }
    sub_category do
      with_sub_category ? Faker::Lorem.words(number: 2).join(" ") : nil
    end

    # Explicitly associate with a syllabus and a belt
    association :syllabus
    association :belt

    # Use a trait to create associated techniques for tests that need them
    trait :with_techniques do
      after(:create) do |technique_type|
        create_list(:technique, 3, technique_type: technique_type)
      end
    end
  end
end
