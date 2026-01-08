FactoryBot.define do
  factory :syllabus do
    # Always use a unique country and year for each syllabus to avoid belt duplication in tests
    country { "UniqueCountry_#{SecureRandom.hex(8)}" }
    year { 2024 + rand(10_000) }

    # Define a trait to create belts and technique types.
    # The `after(:create)` block inside the trait will be executed only when this trait is used.
    trait :with_belts do
      after(:create) do |syllabus|
        # Only use colours that map to unique kyu_numbers in Belt::KYU_MAPPING
        unique_colours = Belt::KYU_MAPPING.keys
        belts =
          unique_colours.map do |colour|
            create(:belt, colour: colour, syllabus: syllabus)
          end

        categories = [
          ["ukemi", "forward roll"],
          ["atemi", "elbow strikes"],
          ["kansetsu", "arm locks"],
          ["shime", "ground strangulations"],
          ["nage", "hip throws"],
          ["ne", "ground arm locks"],
          ["henka", "throwing variations"],
          ["kaeshi", "locking counters"],
          ["bunkai", "grab defences"]
        ]

        categories.each do |category, sub_category|
          create(
            :technique_type,
            syllabus: syllabus,
            belt: belts.sample,
            category: category,
            sub_category: sub_category
          )
        end
      end
    end
  end
end
