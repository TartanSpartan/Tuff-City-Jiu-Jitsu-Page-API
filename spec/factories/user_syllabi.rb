FactoryBot.define do
  factory :user_syllabus do
    # Creates an association with the user factory.
    # When this factory is called, it will automatically create a User.
    association :user

    # Creates an association with the syllabus factory.
    # It will also automatically create a Syllabus.
    association :syllabus
  end
end
