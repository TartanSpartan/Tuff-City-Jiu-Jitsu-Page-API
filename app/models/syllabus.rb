# Maintainers' Rubric — Syllabus
#
# Purpose
# - Represents a country/year syllabus and its taxonomy of belts and technique types.
# - Admin-only flags designate which syllabus is primary or secondary for editing.
#
# Associations
# - has_many :user_syllabi; has_many :users through user_syllabi.
# - has_many :belts (dependent: :destroy) — belt definitions scoped to this syllabus.
# - has_many :technique_types — categories within the syllabus (may own techniques).
#
# Validations
# - country: presence; year: presence + integer; country uniqueness scoped to year.
# - Admin flags: only_one_primary_admin_syllabus; only_one_secondary_admin_syllabus;
#   not_both_primary_and_secondary.
#
# Scopes
# - primary_admin — flag for the primary admin syllabus.
# - secondary_admin — flag for the secondary admin syllabus.
#
# Notes
# - Enforce that only one record globally holds each admin flag; this is done via custom validations.
# - Techniques/videos may be linked via technique_types; keep direct has_many :techniques commented
#   unless needed to simplify queries.

class Syllabus < ApplicationRecord
  # The first belt (by kyu_number) that is visible in the public syllabus view.
  FIRST_VIEWABLE_BELT_KYU = 7
  # belongs_to :user, optional: true
  has_many :user_syllabi, dependent: :destroy
  has_many :users, through: :user_syllabi
  # Uncomment out the following when these features are implemented:
  # has_many :techniques # probably redundant if it has this grandchilded through technique_types?
  # has_many :techniques, through: :technique_types # This method may be more useful
  has_many :belts, dependent: :destroy
  has_many :technique_types # , dependent: :destroy
  # has_one semantic_tree

  validates :country, presence: true
  validates :year, presence: true, numericality: { only_integer: true }
  validates :country, uniqueness: { scope: :year }

  # These enforce that only one syllabus can have the primary/secondary flags set to true globally.
  validate :only_one_primary_admin_syllabus
  validate :only_one_secondary_admin_syllabus
  # Ensure that a single record cannot be both primary *and* secondary
  validate :not_both_primary_and_secondary

  scope :primary_admin, -> { where(is_primary_admin_syllabus: true) } # This is intended to set a primary syllabus for the admin to edit, for specific country/year
  scope :secondary_admin, -> { where(is_secondary_admin_syllabus: true) }

  private

  public

  after_commit :enqueue_warm_cache

  def enqueue_warm_cache
    if Rails.env.development?
      WarmSyllabusCacheJob.perform_now(self.id)
    else
      WarmSyllabusCacheJob.perform_later(self.id)
    end
  end

  # Return an ActiveRecord::Relation of belts visible to the given user for this syllabus.
  # - If `user` is nil, we fall back to showing the public starting belt (Yellow / kyu 7).
  # - The rule: show belts from (user_kyu - 1) up to FIRST_VIEWABLE_BELT_KYU (inclusive).
  #   Example: user_kyu 5 (Green) -> show 4..7.
  # This method returns a relation so callers can eager-load or serialize as needed.
  def visible_belts_for(user)
    current_belt_grade =
      if user
        user
          .belt_grades
          .joins(:belt)
          .where(belts: { syllabus_id: id })
          .order(obtained_at: :desc)
          .first
      end

    user_kyu = current_belt_grade&.belt&.kyu_number || 8
    final_kyu_to_show = [1, user_kyu - 1].max
    kyu_range_to_show = (final_kyu_to_show..FIRST_VIEWABLE_BELT_KYU).to_a

    # Use `reorder` to override any Belt.default_scope ordering (which is kyu_number desc).
    # Limit eager-loading to only what the index view needs: technique types and
    # the techniques themselves (as lightweight link objects). We intentionally
    # avoid loading `videos`, `differences`, `comparisons` and `belt_grades` here
    # because those inflate the payload and are not required for the syllabus
    # list view.
    belts
      .where(kyu_number: kyu_range_to_show)
      .includes(
        technique_types: :techniques
      )
      .reorder(kyu_number: :asc)
  end

  # Validation method to ensure a single syllabus isn't both primary and secondary
  def not_both_primary_and_secondary
    if is_primary_admin_syllabus? && is_secondary_admin_syllabus?
      errors.add(
        :base,
        "A syllabus cannot be set as both primary and secondary."
      )
    end
  end

  # Validation method for the primary admin syllabus flag
  def only_one_primary_admin_syllabus
    # Check if this record is being set as primary AND if another existing record is already primary
    if is_primary_admin_syllabus? &&
         Syllabus.primary_admin.where.not(id: id).exists?
      errors.add(
        :is_primary_admin_syllabus,
        "can only be set on one syllabus at a time."
      )
    end
  end

  # Validation method for the secondary admin syllabus flag
  def only_one_secondary_admin_syllabus
    # Check if this record is being set as secondary AND if another existing record is already secondary
    if is_secondary_admin_syllabus? &&
         Syllabus.secondary_admin.where.not(id: id).exists?
      errors.add(
        :is_secondary_admin_syllabus,
        "can only be set on one syllabus at a time."
      )
    end
  end
end
