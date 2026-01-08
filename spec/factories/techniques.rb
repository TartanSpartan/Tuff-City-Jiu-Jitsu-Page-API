FactoryBot.define do
  factory :technique do
    # Required associations
    association :technique_type
    association :belt

    # Use a sequence to ensure a unique summary for each technique.
    # This prevents validation failures due to duplicate summaries.
    sequence(:summary) { |n| "Technique Summary #{n}" }

    # The `is_different` and `difference_content` attributes are optional,
    # so we'll use traits for them.
    trait :with_difference do
      is_different { true }
      difference_content { Faker::Lorem.sentence(word_count: 5) }
    end

    transient { videos_count { 2 } }

    trait :with_videos do
      after(:create) do |technique, evaluator|
        create_list(:video, evaluator.videos_count, technique: technique)
      end
    end
  end
end
