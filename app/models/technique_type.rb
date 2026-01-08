# Maintainers' Rubric — TechniqueType
#
# Purpose
# - Categorizes techniques within a syllabus (e.g., Takedowns, Groundwork) with optional subcategories.
#
# Associations
# - belongs_to :syllabus — taxonomy is syllabus-specific.
# - belongs_to :belt — category is associated with a belt level.
# - has_many :techniques, dependent: :destroy — techniques within this category.
#
# Validations
# - :category presence; :sub_category presence.
#
# Notes
# - If many-to-many becomes necessary, replace the direct has_many with a join model.
# - Keep required associations (syllabus, belt) to maintain syllabus-specific structure.
#
# Database constraints and maintainers' notes
# - Uniqueness: the combination (syllabus_id, belt_id, category, sub_category)
#   must be unique when `sub_category` is present. This is enforced both by
#   a conditional model validation (allow_blank: true) and by a partial unique
#   index at the DB level for stronger, concurrent safety.
# - Migration: the DB index was added in
#   `db/migrate/20251227000000_add_partial_unique_index_to_technique_types.rb`.
#   Keep that migration when modifying the uniqueness semantics. The partial
#   index uses `WHERE sub_category IS NOT NULL` (Postgres). If you change DB
#   engines, verify partial-index support and adjust the migration accordingly.

# Important note (NULL vs empty-string):
# - The model-level validation is configured with `allow_blank: true`, which
#   treats both `nil` and the empty string `""` as blank for validation
#   purposes. That means the model's uniqueness validation will skip when the
#   value is blank (including empty string), producing a friendly validation
#   behavior for forms.
# - The DB partial unique index uses `WHERE sub_category IS NOT NULL` and thus
#   ignores SQL NULL values only. An empty string (`""`) is NOT NULL at the
#   SQL level and therefore the DB will enforce uniqueness for empty-string
#   values. In short: model.blank? (includes "") != sql NULL.
# - Recommendation: if you prefer to treat empty strings as NULL (so both are
#   excluded from the partial index), normalize inputs (convert `""` -> `nil`)
#   at the application layer (before_validation) and add a migration to
#   backfill existing empty strings if you change semantics.

class TechniqueType < ApplicationRecord
  belongs_to :syllabus # This should not be optional because the Canadian syllabus has technique types which the British syllabus doesn't, and vice-versa
  belongs_to :belt
  has_many :techniques, dependent: :destroy
  validates :category, presence: true
  # sub_category is optional: admins may leave it blank and classify later.
  # Allow blank but still enforce a reasonable maximum length when present.
  validates :sub_category, length: { maximum: 255 }, allow_blank: true

  # Ensure uniqueness of category/sub_category per syllabus and belt when
  # sub_category is present. We rely on a partial unique DB index to enforce
  # this efficiently at the DB level; the model validation is conditional so
  # it does not block records with blank sub_category.
  validates :sub_category,
            uniqueness: {
              scope: %i[syllabus_id belt_id category]
            },
            allow_blank: true

  # Normalize human-entered category text so the first letter of the first
  # word is capitalized (e.g. "bunkai" -> "Bunkai"). This keeps displayed
  # taxonomy tidy while preserving any intentional additional capitalization
  # within the remainder of the string. Use before_validation so the normalized
  # value participates in validations (and uniqueness checks) consistently.
  before_validation :capitalize_category_first_word

  private

  def capitalize_category_first_word
    return if category.blank?

    normalized = category.to_s.strip
    # Capitalize only the first character of the string and leave
    # the remainder unchanged (so "groundwork tactical" -> "Groundwork tactical").
    if normalized.length > 1
      self.category = normalized[0].upcase + normalized[1..-1]
    else
      self.category = normalized.upcase
    end
  end
end
