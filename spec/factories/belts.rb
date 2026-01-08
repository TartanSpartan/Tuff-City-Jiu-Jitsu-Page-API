FactoryBot.define do
  factory :belt do
    # Default to a safe, low-restriction belt to avoid qualification/GI validation traps in tests
    colour { "White" }
    association :syllabus
    # Let the model's before_validation callback assign kyu_number from the colour mapping.
    # Avoid duplicating mapping logic here (it caused mismatches for multi-word colours).
  end
end
