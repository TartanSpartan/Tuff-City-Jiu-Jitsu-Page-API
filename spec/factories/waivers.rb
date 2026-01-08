FactoryBot.define do
  factory :waiver do
    # Define a default set of attributes for a valid waiver.
    # We use Faker to generate realistic and unique data for each factory record.
    participant_name { Faker::Name.name }
    participant_email_address { Faker::Internet.email }

    # We use `user` association to link the waiver to a user.
    # By default, a valid user will be created.
    user

    # Additional fields from the recent migration:
    initials { Faker::Alphanumeric.alpha(number: 3).upcase }
    participant_address { Faker::Address.full_address }

    # Signatures are typically long strings (e.g., Base64 encoded), so we'll use a text generator.
    participant_signature { Faker::Lorem.paragraph(sentence_count: 5) }
    organization_witness_name { Faker::Name.name }
    organization_witness_signature { Faker::Lorem.paragraph(sentence_count: 5) }

    # We'll generate a date of birth for an adult between 18 and 65.
    participant_date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 65) }
    participant_phone { Faker::PhoneNumber.phone_number }
    emergency_contact_name { Faker::Name.name }
    emergency_contact_number { Faker::PhoneNumber.phone_number }
    relationship { Faker::Relationship.familial }

    # We'll set the signed_on date to a recent past date.
    signed_on { Faker::Date.backward(days: 10) }

    # This trait creates a waiver without a user,
    # which is perfect for testing the sign-up flow.
    trait :unsigned do
      # Set the user association to nil.
      user { nil }
    end
  end
end
