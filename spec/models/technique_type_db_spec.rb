require "rails_helper"

RSpec.describe "TechniqueType DB-level constraints", type: :model do
  # These specs ensure the partial unique index at the DB level behaves as
  # expected. We bypass model validations to demonstrate the database will
  # reject duplicates when sub_category is present.

  it "raises an error when inserting duplicate (syllabus, belt, category, sub_category) tuples" do
    first = create(:technique_type, sub_category: "Arms", category: "Sweep")

    dup =
      TechniqueType.new(
        syllabus_id: first.syllabus_id,
        belt_id: first.belt_id,
        category: first.category,
        sub_category: first.sub_category
      )

    # Bypass model validations to force the insert and hit the DB constraint.
    # Assert that ActiveRecord wraps the underlying PG unique-violation so we
    # get a clear, database-level error class (PG::UniqueViolation) as the
    # cause of the ActiveRecord::RecordNotUnique exception.
    expect do dup.save!(validate: false) end.to raise_error(
      ActiveRecord::RecordNotUnique
    ) do |err|
      # Some DB adapters wrap lower-level errors; confirm the underlying
      # cause is the Postgres unique violation class.
      expect(err.cause).to be_a(PG::UniqueViolation)
    end
  end

  it "raises an error when inserting duplicate empty-string sub_category tuples (empty string is NOT NULL)" do
    first = create(:technique_type, sub_category: "", category: "Sweep")

    dup =
      TechniqueType.new(
        syllabus_id: first.syllabus_id,
        belt_id: first.belt_id,
        category: first.category,
        sub_category: first.sub_category
      )

    # Because empty string is distinct from SQL NULL, the partial index will
    # apply and the DB should reject a duplicate empty-string tuple.
    expect do dup.save!(validate: false) end.to raise_error(
      ActiveRecord::RecordNotUnique
    ) do |err|
      expect(err.cause).to be_a(PG::UniqueViolation)
    end
  end

  it "allows multiple rows with NULL/blank sub_category for the same syllabus/belt/category" do
    first = create(:technique_type, sub_category: nil, category: "Position")

    other =
      TechniqueType.new(
        syllabus_id: first.syllabus_id,
        belt_id: first.belt_id,
        category: first.category,
        sub_category: nil
      )

    # Bypassing validations should still allow insertion because the partial
    # index only applies when sub_category IS NOT NULL.
    expect { other.save!(validate: false) }.not_to raise_error
    expect(
      TechniqueType.where(
        syllabus_id: first.syllabus_id,
        belt_id: first.belt_id,
        category: first.category,
        sub_category: nil
      ).count
    ).to be >= 1
  end
end
