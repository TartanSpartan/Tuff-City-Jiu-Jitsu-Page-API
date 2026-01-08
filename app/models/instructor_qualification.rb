#
# InstructorQualification model documentation (maintainers' guide)
#
# Associations:
# - belongs_to :user (optional: true to allow historical records or templates)
# - belongs_to :belt_grade (optional: true, decoupled from grade lifecycle)
# - belongs_to :belt, :qualification
#
# Normalization:
# - effective_qualification_id normalizes arbitrary qualification_id (because with more syllabi, the range of qualification_ids will grow) into 1..4
#   using modulo by QUALIFICATION_BLOCK_SIZE (4). This supports per-syllabus variations
#   while keeping core thresholds (Assistant=2, Instructor=3, Club=4) stable.
#
# Validations:
# - achieved_at required for all but "No qualifications" (qualification_id == 1).
#
# Lifecycle:
# - before_validation: set_effective_qualification_id
class InstructorQualification < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :belt_grade, optional: true
  belongs_to :belt
  belongs_to :qualification

  # Constant used for normalization logic (4 levels per syllabus)
  QUALIFICATION_BLOCK_SIZE = 4

  # Callback to automatically calculate the normalized ID before saving the record
  before_validation :set_effective_qualification_id

  # TODO: Consider adding database constraints (null: false) and indices for user_id, belt_id, qualification_id for performance.

  # Only validate achievement date if it's something other than "No Qualifications" (qualification_id: 1)
  validates :achieved_at,
            presence: {
              message: "date must not be blank for instructor qualification"
            },
            unless: -> { qualification_id == 1 }

  # Sanity check: if present, effective_qualification_id must be within 1..QUALIFICATION_BLOCK_SIZE
  validates :effective_qualification_id,
            inclusion: {
              in: 1..QUALIFICATION_BLOCK_SIZE
            },
            allow_nil: true

  private

  # Calculates the normalized qualification ID (1 through 4) using modulo arithmetic.
  def set_effective_qualification_id
    raw_id = self.qualification_id

    # Only proceed if the raw qualification_id is present and is an integer.
    if raw_id.present? && raw_id.is_a?(Integer)
      # Formula: ((Raw ID - 1) % Block Size) + 1
      # Example: Raw ID 6 (British Assistant Instructor) -> ((6 - 1) % 4) + 1 = 1 + 1 = 2
      # Example: Raw ID 2 (Canadian Assistant Instructor) -> ((2 - 1) % 4) + 1 = 1 + 1 = 2
      self.effective_qualification_id =
        ((raw_id - 1) % QUALIFICATION_BLOCK_SIZE) + 1
    else
      # Handle cases where the ID might not be set yet (e.g., during initialization before association)
      # Note: The database constraint ensures this must eventually be set before persistence.
      self.effective_qualification_id = nil
    end
  end
end
