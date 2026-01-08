FactoryBot.define do
  factory :belt_grade do
    # Required association for the :belt (default to Yellow to avoid instructor qualification constraints)
    belt { association(:belt, colour: "Yellow") }

    # By default create a user who owns a gi so graded belt factories are valid
    association :user, factory: :user, owns_gi: true

    # Trait to explicitly avoid creating a user when needed
    trait :no_user do
      user { nil }
    end

    obtained_at { Faker::Time.backward(days: 30) }
  end
end
