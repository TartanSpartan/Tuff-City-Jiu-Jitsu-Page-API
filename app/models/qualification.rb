# Maintainers' Rubric — Qualification
#
# Purpose
# - Represents a discrete qualification level that is tied to a specific Belt.
# - Serves as the source record for an InstructorQualification (one-to-one per qualification).
#
# Key associations
# - belongs_to :belt — every qualification is defined within the context of a belt (colour/kyu).
# - has_one :instructor_qualification — normalized/derived link to the instructor’s achieved level.
#
# Lifecycle & normalization
# - before_save :capitalize_level — ensures the textual level is consistently capitalized
#   to avoid accidental duplicates due to case differences (e.g., "assistant" vs "Assistant").
#
# Validations & expectations
# - No explicit validations here at present; upstream usage constrains values via admin tooling.
# - Consider future guards such as presence/uniqueness for :level scoped by :belt_id to avoid
#   duplicates if CRUD is opened up beyond admin flows.
#
# Cross-model notes
# - InstructorQualification uses this model to represent the achieved level per syllabus.
# - Belt-driven conventions (e.g., KYU mapping) may influence how qualifications are displayed
#   but are not enforced here; keep Qualification minimal and let domain rules live where used.

class Qualification < ApplicationRecord
  before_save :capitalize_level
  belongs_to :belt
  has_one :instructor_qualification

  private

  def capitalize_level
    self.level.capitalize! if self.level.present?
  end
end
