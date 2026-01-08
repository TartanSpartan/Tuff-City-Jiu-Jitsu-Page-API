#
# BeltGrade model documentation (maintainers' guide)
#
# Effective kyu normalization:
# - effective_kyu_grade is derived from belt.kyu_number and normalized into 1..8.
# - Convention: 1 = Brown (highest kyu), 8 = White (lowest kyu).
#
# Callback behavior:
# - effective_kyu_grade is recalculated before validation when belt_id changes
#   using Rails dirty tracking (will_save_change_to_belt_id?).
#
# Domain rules:
# - GI required to grade for coloured belts (effective kyu <= 7); not required for White (8).
# - Instructor qualification thresholds:
#   * Purple (4th kyu) and Light Blue (3rd kyu) → Assistant Instructor (qualification_id >= 2)
#   * Dark Blue (2nd kyu) → Instructor (qualification_id >= 3)
#   * Brown (1st kyu) → Club Instructor (qualification_id >= 4)
# - First-aid requirement: Brown (1st kyu) requires has_first_aid_qualification = true
#   with a recorded first_aid_achievement_date.
#
# Validation notes:
# - effective_kyu_grade has numericality enforced (1..8) when present, but may be nil
#   when no belt is associated or if belt data is incomplete. Presence of belt and
#   related correctness drive overall validity.
class BeltGrade < ApplicationRecord
  belongs_to :user
  belongs_to :belt
  has_one :instructor_qualification, dependent: :nullify

  # Callback: calculate the effective kyu grade (1-8) before validation ---
  # This ensures the new column is correctly set on every create/update.
  # Use Rails dirty tracking on the foreign key, not the association object.
  before_validation :set_effective_kyu_grade, if: :will_save_change_to_belt_id?

  # Effective kyu number constants
  # These constants reliably refer to the effective Kyu rank number (1=Brown/Highest, 8=White/Lowest)
  PURPLE_BELT_KYU = 4 # Effective 4th kyu
  LIGHT_BLUE_BELT_KYU = 3 # Effective 3rd kyu
  DARK_BLUE_BELT_KYU = 2 # Effective 2nd kyu
  BROWN_BELT_KYU = 1 # Effective 1st kyu

  # Qualification IDs refer to the Qualifications model's specific IDs.
  ASSISTANT_INSTRUCTOR_ID = 2
  INSTRUCTOR_ID = 3
  CLUB_INSTRUCTOR_ID = 4

  # Validate presence of the obtained_at timestamp
  validates :obtained_at, presence: true

  # Validate effective kyu is an integer within 1..8 when present
  validates :effective_kyu_grade,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 8
            },
            allow_nil: true # Allow nil to accommodate belts without a kyu grade (edge cases, dan grades in the future, etc.)

  validate :must_be_assistant_instructor_for_purple_or_light_blue_belt
  validate :must_be_instructor_for_dark_blue_belt
  validate :must_be_club_instructor_for_brown_belt
  validate :must_have_first_aid_for_brown_belt
  validate :gi_required_to_grade

  def time_held
    # Calculate the duration since obtained_at in years and months
    now = Date.current
    days_held = (now - obtained_at).to_i

    years = days_held / 365
    remaining_days = days_held % 365
    months = remaining_days / 30

    if years > 0
      "#{years} year#{"s" unless years == 1} and #{months} month#{"s" unless months == 1}"
    elsif months > 0
      "#{months} month#{"s" unless months == 1}"
    else
      "Less than a month"
    end
  end

  def grade_name
    # Derive a human-readable grade name (e.g., "Yellow")
    # Prefer the associated belt's colour; fallback to kyu → colour mapping.
    return belt.colour if belt&.colour.present?

    case effective_kyu_grade
    when 8
      "White"
    when 7
      "Yellow"
    when 6
      "Orange"
    when 5
      "Green"
    when 4
      "Purple"
    when 3
      "Light Blue"
    when 2
      "Dark Blue"
    when 1
      "Brown"
    else
      "Unknown"
    end
  end

  private

  def set_effective_kyu_grade
    # Method to calculate the effective kyu (1-8) from the raw kyu number
    raw_kyu = self.belt&.kyu_number

    if raw_kyu.present? && raw_kyu.is_a?(Integer)
      # Robust calculation: effective_kyu = ((raw_kyu - 1) % 8) + 1
      self.effective_kyu_grade = ((raw_kyu - 1) % 8) + 1
    else
      # If belt is not set, set to nil or 0, or let validation handle it.
      self.effective_kyu_grade = nil
    end
  end

  def gi_required_to_grade
    # Custom validation to enforce GI ownership for colored belts (Yellow Belt and above).
    # Yellow Belt is ID 7. White Belt is ID 8. We assume lower IDs are higher ranks.

    # Only enforce this rule when a user is present.
    return unless user.present?

    # 1. Safely check if the user owns a gi
    owns_gi = user.owns_gi

    # Checks if the effective grade is Yellow Belt (7) or a higher rank (less than 7).
    # This works for any and all syllabi now.
    is_coloured_belt_or_higher =
      self.effective_kyu_grade.present? && self.effective_kyu_grade <= 7

    # Edge case: if the user does NOT own a gi AND they are recorded in the database as attempting to grade to a coloured belt or higher...
    if !owns_gi && is_coloured_belt_or_higher
      # Add an error message to the belt_id field and a general base error
      errors.add(
        :belt_id,
        "The user must own a gi to be graded to Yellow Belt (Kyu 7) or any higher rank."
      )
      errors.add(
        :base,
        "Grading failed: GI ownership is mandatory for this rank."
      )
    end
  end

  def must_be_assistant_instructor_for_purple_or_light_blue_belt
    # This validation applies to both Purple (4th kyu) and Light Blue (3rd kyu) belts. A student without that qualification cannot grade to either.
    if self.effective_kyu_grade == PURPLE_BELT_KYU ||
         self.effective_kyu_grade == LIGHT_BLUE_BELT_KYU
      if user.present?
        # Check if the user has an InstructorQualification with an ID of 2 (Assistant) or higher (3 or 4).
        unless user
                 .instructor_qualifications
                 .where("qualification_id >= ?", ASSISTANT_INSTRUCTOR_ID)
                 .exists?
          errors.add(
            :belt_id,
            "cannot be #{belt_label} until the Assistant Instructor qualification is achieved."
          )
        end
      end
    end
  end

  def must_be_instructor_for_dark_blue_belt
    if self.effective_kyu_grade == DARK_BLUE_BELT_KYU
      if user.present?
        # Check if the user has an InstructorQualification with an ID of 3 (Instructor) or higher (4).
        unless user
                 .instructor_qualifications
                 .where("qualification_id >= ?", INSTRUCTOR_ID)
                 .exists?
          errors.add(
            :belt_id,
            "cannot be #{belt_label} until the Instructor qualification is achieved."
          )
        end
      end
    end
  end

  def must_be_club_instructor_for_brown_belt
    if self.effective_kyu_grade == BROWN_BELT_KYU
      if user.present?
        # Check if the user has an InstructorQualification with an ID of 4 (Club Instructor; there is no higher qualification for a kyu grade, dan grades will be considered separately, down the line)
        unless user
                 .instructor_qualifications
                 .where("qualification_id >= ?", CLUB_INSTRUCTOR_ID)
                 .exists?
          errors.add(
            :belt_id,
            "cannot be #{belt_label} until the Club Instructor qualification is achieved."
          )
        end
      end
    end
  end

  # Note: the above validation and method are actually inaccurate, you must be club_instructor for *shodan* and above, but
  # we'll adjust that later when dan grades are implemented. For now, club instructors are a good indication of which users
  # (and ergo which belt grades) should be eligible as admin, so we'll retain it.

  def belt_label
    colour = belt&.colour || "the selected"
    kyu = effective_kyu_grade || belt&.kyu_number
    kyu.present? ? "#{colour} Belt (#{kyu.ordinalize} kyu)" : "#{colour} Belt"
  end

  def must_have_first_aid_for_brown_belt
    # The rule only applies when saving the Brown Belt.
    if self.effective_kyu_grade == BROWN_BELT_KYU
      if user.present?
        # Check the boolean flag directly on the User model
        unless user.has_first_aid_qualification
          errors.add(
            :belt_id,
            "cannot be Brown Belt (#{BROWN_BELT_KYU}st kyu) until a valid First Aid and CPR qualification is held."
          )
        end
      end
    end
  end
end
