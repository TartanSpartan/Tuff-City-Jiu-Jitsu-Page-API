# spec/factories/videos.rb
FactoryBot.define do
  factory :video do
    # Creates an association with the Technique model.
    # Factory Bot will automatically look for and use a 'technique' factory.
    association :technique

    # Use a sequence to ensure the URL is unique for each video.
    # Produce canonical YouTube watch URLs so model validation passes.
    sequence(:url) { |n| "https://www.youtube.com/watch?v=test_vid_#{n}" }

    # Use a sequence to ensure the country is unique.
    sequence(:country) { |n| "Country_#{n}" }

    # Generates a random year greater than 1900 to satisfy the validation.
    year { Faker::Number.between(from: 1901, to: Date.today.year) }

    # This trait explicitly creates a technique association.
    # It is required for the serializer test spec to work correctly, as it
    # simulates the scenario where a video has a technique.
    trait :with_technique do
      association :technique, factory: :technique
    end
  end
end
