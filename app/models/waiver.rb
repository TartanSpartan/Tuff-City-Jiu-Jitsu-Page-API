# Maintainers' Rubric — Waiver
#
# Purpose
# - Records participant waiver details including contact info, signatures, and legal checks.
# - Supports admin workflow via outstanding scope and witness fields on update.
#
# Associations
# - belongs_to :user, optional: true — waivers may be created before a user account exists.
#
# Lifecycle
# - before_save :capitalize_fields — normalizes capitalization of key free-text fields.
#
# Scopes
# - outstanding — waivers missing organization_witness_name.
#
# Validations
# - One waiver per user (user_id uniqueness) but allow_nil to support pre-account waivers.
# - participant_email_address: presence + uniqueness (case-insensitive) + format.
# - Form field presence: participant_* and emergency_contact_* fields, relationship, signed_on.
# - Organization witness presence only on update (admin completion step).
# - Legal age check via validate_legal_age (must be 18+ at signed_on date).
#
# Leap-year handling
# - Birthdays on Feb 29 are treated as occurring on Mar 1 in non-leap years for the
#   purposes of turning a whole number of years old (e.g. 18). The age calculation is
#   performed using calendar month/day comparisons and is centralized in #age_on.
#
# Utility
# - .outstanding_count — counts outstanding waivers via scope.

class Waiver < ApplicationRecord
  belongs_to :user, optional: true

  # Normalize inputs before validations so validations operate on canonical values
  before_validation :normalize_email
  before_validation :normalize_fields
  before_validation :normalize_phones

  # Treat nil or blank witness name as outstanding
  scope :outstanding, -> { where(organization_witness_name: [nil, ""]) }

  # This validation is designed to enforce that each user can only have one waiver each
  # However, allow_nil means that a waiver can be signed and not require a registered user to be signed as such; they can be associated later if necessary
  # One waiver per registered user; allow multiple pre-account (nil) waivers
  validates :user_id, uniqueness: true, allow_nil: true

  validates :participant_email_address,
            presence: true,
            uniqueness: {
              case_sensitive: false,
              message: "is already taken"
            },
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              message: "invalid email format"
            }

  validate :validate_legal_age

  # Form validations
  validates :participant_name, presence: true
  validates :initials, presence: true
  validates :participant_address, presence: true
  validates :participant_signature, presence: true
  validates :participant_phone, presence: true
  validates :emergency_contact_name, presence: true
  validates :emergency_contact_number, presence: true
  validates :relationship, presence: true
  validates :signed_on, presence: true
  validates :participant_date_of_birth, presence: true

  # Organization Witness Fields: Only require presence on subsequent updates
  # This assumes the admin will update the record to mark it complete.
  validates :organization_witness_name, presence: true, on: :update
  validates :organization_witness_signature, presence: true, on: :update

  def self.outstanding_count
    self.outstanding.count
  end

  private

  def normalize_email
    if participant_email_address.present?
      self.participant_email_address =
        participant_email_address.to_s.strip.downcase
    end
  end

  def normalize_fields
    # Conservative normalization: strip/squish whitespace, upcase initials
    self.participant_name =
      participant_name.to_s.squish if participant_name.present?
    self.initials = initials.to_s.gsub(/\s+/, "").upcase if initials.present?
    self.participant_address =
      participant_address.to_s.squish if participant_address.present?
    self.organization_witness_name =
      organization_witness_name.to_s.squish if organization_witness_name.present?
    self.emergency_contact_name =
      emergency_contact_name.to_s.squish if emergency_contact_name.present?
    self.relationship = relationship.to_s.squish if relationship.present?
  end

  def normalize_phones
    if participant_phone.present?
      # Store only digits; we will consider E.164 in the future for international number handling
      self.participant_phone = participant_phone.to_s.gsub(/[^0-9+]/, "")
    end
    if emergency_contact_number.present?
      self.emergency_contact_number =
        emergency_contact_number.to_s.gsub(/[^0-9+]/, "")
    end
  end

  def validate_legal_age
    if participant_date_of_birth.present? && signed_on.present?
      if age_on(signed_on) < 18
        errors.add(:participant_date_of_birth, "must be 18 years or older")
      end
    end
  end

  public

  # Calculate the age (integer years) for this waiver's participant_date_of_birth
  # at the given date/time. The argument may be a Date, Time, DateTime, or
  # ActiveSupport::TimeWithZone; it will be converted to a Date for calendar-day
  # calculations. This centralizes leap-year handling and makes the rule testable.
  def age_on(at)
    return nil unless participant_date_of_birth.present? && at.present?
    at_date = at.to_date
    dob = participant_date_of_birth

    age = at_date.year - dob.year
    # Compare month/day to avoid leap-year yday discrepancies (dob.yday is relative to birth year)
    if at_date.month < dob.month ||
         (at_date.month == dob.month && at_date.day < dob.day)
      age -= 1
    end
    age
  end
end
