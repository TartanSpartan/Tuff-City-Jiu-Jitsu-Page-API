#
# Belt model documentation (maintainers' guide)
#
# KYU_MAPPING:
# - Maps standard colour names to kyu numbers. Convention here: White = 8 (lowest kyu number), Brown = 1 (highest kyu number).
# - Some specs set explicit kyu_number to decouple expectations from colour mapping.
#
# Default ordering:
# - default_scope orders by kyu_number desc (White first → highest numeric value).
#
# Callbacks:
# - capitalize_colour: ensures colour is capitalized for mapping and validation.
# - assign_kyu_number: sets kyu_number from colour if not explicitly provided; adds a validation error if colour is unrecognized.
#
# Validation notes:
# - kyu_number must be present, integer, and unique within a syllabus.
# - syllabus is optional to allow global/reference belts.
class Belt < ApplicationRecord
  # --- CONSTANTS ---
  # Define the standard color-to-Kyu mapping.
  # Note: Kyu numbers count DOWN. White = highest rank number (e.g., 8th Kyu), Brown = lowest (e.g., 1st Kyu).
  KYU_MAPPING = {
    "White" => 8,
    "Yellow" => 7,
    "Orange" => 6,
    "Green" => 5,
    "Purple" => 4,
    "Light Blue" => 3,
    "Dark Blue" => 2,
    "Brown" => 1
  }.freeze

  has_many :belt_grades, dependent: :destroy
  has_many :instructor_qualifications, dependent: :nullify
  has_many :qualifications, dependent: :nullify
  has_many :techniques
  has_many :technique_types, dependent: :destroy
  belongs_to :syllabus, optional: true

  # --- SCOPES ---
  # Ensures all belt queries are ordered from highest Kyu (White) to lowest (Brown)
  default_scope { order(kyu_number: :desc) }

  before_validation :capitalize_colour
  before_validation :assign_kyu_number, on: :create

  validates :colour, presence: true
  validates :kyu_number, presence: true, numericality: { only_integer: true }
  validates :kyu_number,
            uniqueness: {
              scope: :syllabus_id,
              message:
                "A belt with this Kyu number already exists for this syllabus."
            },
            allow_nil: true

  # If both colour and kyu_number are present, ensure they align with known mapping.
  # Unknown colours are allowed (e.g., test-specific), so we only enforce consistency
  # when the colour exists in KYU_MAPPING.
  validate :colour_matches_known_kyu,
           if: -> { colour.present? && kyu_number.present? }

  private

  def capitalize_colour
    # Use titleize to preserve multi-word colours (e.g. "Light Blue") so
    # they match the keys in KYU_MAPPING exactly.
    self.colour = self.colour.to_s.titleize if self.colour.present?
  end

  # Automatically set the kyu_number based on the colour
  def assign_kyu_number
    # Only try to assign if kyu_number hasn't been explicitly set and colour is known
    if self.kyu_number.nil? && self.colour.present?
      # Use the capitalized colour to look up the number
      self.kyu_number = KYU_MAPPING[self.colour]

      # Optional: Add a validation error if the colour is unrecognized
      unless self.kyu_number
        errors.add(
          :colour,
          "is not a recognized belt color for Kyu assignment."
        )
      end
    end
  end

  # Ensure recognized colours use the expected kyu_number.
  def colour_matches_known_kyu
    expected = KYU_MAPPING[self.colour]
    return unless expected # allow custom/unrecognized colours without enforcement
    if self.kyu_number != expected
      errors.add(
        :kyu_number,
        "does not match the expected value for #{self.colour} (expected #{expected})."
      )
    end
  end
end
