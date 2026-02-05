# Maintainers' Rubric — Technique
#
# Purpose
# - Represents an individual technique within a syllabus/belt/category, with related videos.
# - Supports nested video creation/update via accepts_nested_attributes_for.
#
# Associations
# - belongs_to :belt — belt context for the technique.
# - belongs_to :technique_type — categorization within syllabus.
# - has_many :videos (inverse_of: :technique, dependent: :destroy) — instructional assets.
# - has_many :differences — where this technique is the subject of a comparison.
# - has_many :comparisons, class_name: "Difference", foreign_key: "compared_to_technique_id" —
#   where this technique is the object of a comparison.
#
# Lifecycle
# - before_validation :titleize_summary — ensures consistent capitalization and
#   whitespace normalization (strip + squish + titleize).
# - accepts_nested_attributes_for :videos, allow_destroy: true, reject_if: :all_blank — permits
#   atomic updates to a technique and its videos.
#
# Validations
# - summary: presence; minimum length; uniqueness scoped by [belt_id, technique_type_id].
# - technique_type_id, belt_id: presence.

class Technique < ApplicationRecord
  belongs_to :belt
  belongs_to :technique_type

  # delegate :kyu_number, to: :belt, allow_nil: true
  # Uncomment the above line if technique.belt.kyu_number is frequently used

  # A technique can be the subject of a comparison (e.g., this technique differs from...)
  has_many :differences, dependent: :destroy
  # A technique can also be the object of a comparison (e.g., this technique is compared to...)
  has_many :comparisons,
           class_name: "Difference",
           foreign_key: "compared_to_technique_id",
           dependent: :destroy

  has_many :videos, inverse_of: :technique, dependent: :destroy
  # This is the key to creating videos and techniques in a single request.
  # The :allow_destroy option means we can also delete videos via the
  # parent technique's update action.
  accepts_nested_attributes_for :videos,
                                allow_destroy: true,
                                reject_if: :all_blank

  # This validation enforces the business rule that a technique must have at least one video. Actually for now we're going to put a conditional validation on the Video model.
  # validates :videos, presence: true

  before_validation :titleize_summary

  after_commit :enqueue_syllabus_warm

  def enqueue_syllabus_warm
    # technique -> technique_type -> syllabus
    sid = technique_type&.syllabus_id
    return unless sid
    if Rails.env.development?
      WarmSyllabusCacheJob.perform_now(sid)
    else
      WarmSyllabusCacheJob.perform_later(sid)
    end
  end

  # Validations
  validates :summary,
            presence: true,
            length: {
              minimum: 5
            },
            uniqueness: {
              case_sensitive: false,
              scope: %i[belt_id technique_type_id]
            }
  validates :technique_type_id, presence: true
  validates :belt_id, presence: true
  # validates :belt_grade_id, presence: true

  private

  def titleize_summary
    return unless summary.present?

    normalized = summary.to_s.strip.squish
    self.summary = normalized.titleize
  end
end
