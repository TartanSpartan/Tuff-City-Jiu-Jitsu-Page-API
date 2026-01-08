# Maintainers' Rubric — Difference
#
# Purpose
# - Captures a comparison between two techniques (base technique vs. compared_to_technique).
# - Stores human-readable content describing how they differ.
#
# Associations
# - belongs_to :technique — the primary technique that this record references.
# - belongs_to :compared_to_technique, class_name: "Technique" — the secondary technique.
#
# Validations
# - :content presence — a difference must have descriptive content.
# - cannot_compare_to_self — prevents comparing a technique to itself.
#
# Notes
# - Cross-syllabus comparisons are allowed and encouraged; do NOT constrain differences to the
#   same syllabus or belt context.
# - Directionality policy (A vs B vs B vs A) can be decided later; until then, keep validations
#   permissive and avoid canonicalizing the pair in-model.
# - Keep this model focused on relational integrity and minimal validations; UI/UX should handle
#   richer formatting or additional structure for content.

class Difference < ApplicationRecord
  # Associations
  # This association defines the "base" technique for the comparison.
  belongs_to :technique

  # This association defines the "other" technique being compared to the base.
  belongs_to :compared_to_technique, class_name: "Technique"

  # Validations
  validates :content, presence: true
  validate :cannot_compare_to_self

  private

  def cannot_compare_to_self
    if technique_id == compared_to_technique_id
      errors.add(:base, "A technique cannot be compared to itself")
    end
  end
end
