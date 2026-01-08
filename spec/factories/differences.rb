FactoryBot.define do
  factory :difference do
    # Creates the base technique for the comparison.
    association :technique, factory: :technique

    # Creates the "other" technique being compared against.
    association :compared_to_technique, factory: :technique

    # Generates a paragraph of lorem ipsum text for the content.
    content { Faker::Lorem.paragraph }
  end
end
