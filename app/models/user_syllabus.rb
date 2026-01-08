# Maintainers' Rubric — UserSyllabus
#
# Purpose
# - Joins users to syllabi, representing a user's enrollment or access to a syllabus.
#
# Associations
# - belongs_to :user
# - belongs_to :syllabus
#
# Validations
# - Uniqueness of user_id scoped by syllabus_id — one entry per user per syllabus.

class UserSyllabus < ApplicationRecord
  belongs_to :user
  belongs_to :syllabus

  validates :user_id,
            uniqueness: {
              scope: :syllabus_id,
              message: "has already been taken for this syllabus"
            }
  # Explicitly validate presence of the foreign keys for clarity and to make
  # it easy to assert presence in model specs. `belongs_to` implies presence
  # in modern Rails, but an explicit validation makes the contract visible.
  validates :user_id, :syllabus_id, presence: true
end
