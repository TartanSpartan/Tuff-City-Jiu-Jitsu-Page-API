class AddPartialUniqueIndexToTechniqueTypes < ActiveRecord::Migration[6.1]
  # Purpose:
  # - Add a partial unique index so that, for any non-null sub_category, the
  #   tuple (syllabus_id, belt_id, category, sub_category) is unique.
  # - We intentionally keep sub_category nullable so that records without a
  #   subcategory (admins haven't classified them yet) are allowed and can be
  #   created multiple times for the same syllabus/belt/category.
  #
  # Notes for maintainers:
  # - This migration uses a partial index (`WHERE sub_category IS NOT NULL`) —
  #   Postgres supports this pattern natively. If you intend to run on a DB
  #   engine that does not support partial indexes, adapt the migration to use
  #   a functional index or other enforcement strategy.
  # - The model includes a conditional uniqueness validation, but the DB index
  #   is the authoritative enforcement for concurrency and non-Rails writes.

  def change
    add_index :technique_types,
              %i[syllabus_id belt_id category sub_category],
              unique: true,
              name:
                "index_technique_types_on_syllabus_belt_category_subcat_not_null",
              where: "sub_category IS NOT NULL"
  end
end
