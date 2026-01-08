# frozen_string_literal: true
class SyllabusLimitedSerializer < ActiveModel::Serializer
  # Inherit basic attributes from the Syllabus model
  attributes(
    :id,
    :country,
    :year
    # :created_at,
    # :updated_at
  )

  # DO NOT include top-level technique_types here; BeltSerializer will handle them.
  # has_many :technique_types # Keep the API response cleaner

  # Yellow belt is the first page/belt of the syllabus with viewable content.
  # We start displaying the syllabus from this grade, regardless of the user's rank.
  FIRST_VIEWABLE_BELT_KYU = 7

  # Key takeaways:
  # - Always scope belt-grade lookups to the current syllabus (belt.syllabus_id == object.id).
  # - The display window should end at "one step above" the user's current grade.
  #   I.e., if a user's kyu is 5 (Green), show 4..7 (one above, Purple in this case, through  Yellow).
  # - Prefer kyu_number semantics (Belt.kyu_number and BeltGrade.effective_kyu_grade)
  #   over raw database IDs when calculating ranges. The codebase's canonical mapping
  #   is Belt::KYU_MAPPING and the `kyu_number` column; the old implementtion used
  #   ID-based logic which is fragile if IDs change or when belts are seeded differently.

  # Declare `belts` as a relationship so AMS can treat it as such and populate
  # a top-level `included` array when requested via `include:`.
  has_many :belts, serializer: BeltSerializer

  # Return the AR collection for belts (do not pre-serialize to JSON here).
  def belts
    user = scope && scope[:current_user]
    object.visible_belts_for(user)
  end
end
