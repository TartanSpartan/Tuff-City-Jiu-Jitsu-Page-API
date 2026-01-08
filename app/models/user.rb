# Maintainers' Rubric — User
#
# Purpose
# - Core account model integrating Devise authentication and Google OAuth (omniauthable).
# - Holds training-related flags and associations used by belt/qualification logic.
#
# Auth & identity
# - Devise modules: database_authenticatable, registerable, recoverable, rememberable, validatable, omniauthable.
# - OAuth providers: google_oauth2; supports account linking via provider/uid and email matching.
# - Password handling: skip_password_validation for OAuth flows; conditional validations
#   based on whether a password is being changed (password_is_being_changed?).
# - Email normalization: downcase before save.
#
# Domain attributes (used by validations in other models)
# - has_first_aid_qualification (boolean) and first_aid_achievement_date (date):
#   If the flag is true, a date is required (validated here).
# - owns_gi (boolean): referenced by BeltGrade rules (GI ownership required for certain kyu levels).
# - is_admin (boolean): simple role check via is_admin? helper.
#
# Associations
# - Waiver: has_one (retained even if user is deleted via nullify for record-keeping).
# - Syllabi: has_many through user_syllabi.
# - Instructor qualifications: has_many, plus current_instructor_qualification (latest by achieved_at).
# - Belt grades: has_many, plus current_belt_grade (latest by obtained_at).
# - Qualifications: has_many through instructor_qualifications.
#
# OmniAuth flows
# - from_omniauth(auth): verifies Google ID token and links/creates user, skipping password validation.
# - from_google_token(id_token): API-friendly token verification path used in server-side auth.
#
# Validation highlights
# - Names: presence/length/format (skipped for from_omniauth flag to support external identity).
# - Email: presence, uniqueness (case-insensitive), format.
# - Password: presence/min length/confirmation gated by OAuth flag and change intent.
#
# Notes
# - Be mindful of cross-model domain rules (BeltGrade, InstructorQualification) that rely
#   on user flags. Keep User’s concerns limited to auth and base profile + simple validations.
# 
# TODO:
# Extract resilient name fallback: when auth.info.first_name/last_name are missing, parse
# auth.info.name (split or sensible fallback) to populate first_name and last_name. Add tests
# for edge cases (single names, multi-part names).
# 
# Keep safe credential checks: wrap access to auth[:credentials] with presence checks before
# reading :token, :refresh_token, or :expires_at; convert expires_at to Time.at(...).to_datetime
# defensively.
# 
# Preserve explicit Google payload handling: prefer payload['sub'] as the canonical Google UID,
# and use verified token payload fields (email, given_name, family_name) rather than unverified
# auth.info when available.
# 
# Retain specific error handling/logging patterns: separate rescue for
# Google::Auth::IDTokens::VerificationError (and signature errors) to aid diagnostics; keep clear
# log messages including context (provider, uid, email) when linking or creating accounts.
# 
# SecureRandom.hex are both acceptable; keep the existing approach but centralize it in one helper
# to make intent explicit.
# 
# Note for refactor: move above logic into a small service Users::GoogleAuthenticator (or similar)
# that returns a persisted or unsaved User, keeping User model thin; leave comments in user.rb
# referencing the service extraction for future commits.

require "googleauth"
require "googleauth/id_tokens"
# puts "--- User Model Loaded ---"

class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]
  #  , :provider_ignores_state => true # This is a debug test setting for google_oauth2

  # Associations

  has_one :waiver, dependent: :nullify 
  # We will retain user waivers even if they delete their accounts, for record keeping purposes
  # as they may wish to continue training, so closing a user account does not result in waiver
  # deletion; however, in production mode ensure that this is in compliance with data protection
  # regulations in BC and elsewhere as applicable

  has_many :user_syllabi, dependent: :destroy
  has_many :syllabi, through: :user_syllabi

  has_many :instructor_qualifications, dependent: :nullify
  has_one :current_instructor_qualification,
          -> { order(achieved_at: :desc) },
          class_name: "InstructorQualification"

  has_many :belt_grades, dependent: :nullify
  has_one :current_belt_grade,
          -> { order(obtained_at: :desc) },
          class_name: "BeltGrade"

  has_many :qualifications, through: :instructor_qualifications

  # has_secure_password

  attr_accessor :from_omniauth
  before_save :downcase_email

  # Validations
  # Do not need to validate belt_grade_id, qualifications_id as this is configurable only by admins or
  # instructors and handled in other models
  # And these can be further constrained to sane input using dropdown menus and no other means of input
  validates :first_name,
            presence: true,
            length: {
              maximum: 50
            },
            format: {
              with: /\A[\p{L}\p{M}\p{Pd}ʼ’‘'\- ]+\z/,
              message:
                "only allows letters and associated accents, diacritics, punctuation, etc"
            },
            unless: :from_omniauth

  validates :last_name,
            presence: true,
            length: {
              maximum: 50
            },
            format: {
              with: /\A[\p{L}\p{M}\p{Pd}ʼ’‘'\- ]+\z/,
              message:
                "only allows letters and associated accents, diacritics, punctuation, etc"
            },
            unless: :from_omniauth

  validates :email,
            presence: true,
            uniqueness: {
              case_sensitive: false,
              message: "is already taken"
            },
            format: {
              with: /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i,
              message: "invalid email format"
            }

  # Compare the three above validations, second is worst, third may be best
  # There may be some edge cases with symbols like plus signs, how would we handle these?

  validates :password,
            presence: true,
            length: {
              minimum: 8
            },
            confirmation: true,
            unless: -> { from_omniauth? || !password_is_being_changed? }
  validates :password_confirmation,
            presence: true,
            unless: -> { from_omniauth? || !password_is_being_changed? }
  # TODO: Add special characters check, here and in the client

  validate :first_aid_achievement_date_required

  def full_name
    "#{first_name.titleize} #{last_name.titleize}".strip
    # Titleize helps with edge cases with mixed capitalization like FitzGerald
  end

  def from_omniauth?
    !!@from_omniauth # Converts truthy/falsy to true/false
  end

  def password_required?
    return false if skip_password_validation
    super
  end

  attr_accessor :skip_password_validation

  # Class method to find or create a user from the OmniAuth hash
  def self.from_omniauth(auth)
    begin
      id_token = auth.dig(:extra, :id_token)
      unless id_token.present?
        raise StandardError.new(
                "Google ID token is missing in the OmniAuth hash."
              )
      end

      client_id = Rails.application.credentials.dig(:API, :google_client_id)
      unless client_id.present?
        raise StandardError.new(
                "Google client ID not configured in Rails credentials."
              )
      end

      # Verify the ID token payload
      payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: client_id)
    rescue => e
      Rails.logger.error("Google ID token verification failed: #{e.message}")
      return nil
    end

    email = payload["email"].downcase
    provider = auth[:provider]
    uid = auth[:uid]

    # 1. Try to find user by provider/uid (Returning OAuth user)
    user = find_by(provider: provider, uid: uid)

    # 2. If not found, try to find the user by email (For linking existing accounts)
    unless user
      user = find_by(email: email)

      if user
        # Existing email/password user found. Link the OAuth account.
        user.provider = provider
        user.uid = uid
        Rails.logger.info(
          "Existing user (ID: #{user.id}) linked to Google account."
        )
      end
    end

    # 3. If still not found, initialize a new user object
    user = new(provider: provider, uid: uid, email: email) unless user

    # Set/Update attributes from payload/auth hash (common to new and linked users)
    user.first_name = payload["given_name"] || auth.dig(:info, :first_name)
    user.last_name = payload["family_name"] || auth.dig(:info, :last_name)
    user.email = email # Always set the email from the verified payload (downcased)

    # Set credentials
    user.google_token = auth.dig(:credentials, :token)
    user.google_refresh_token = auth.dig(:credentials, :refresh_token)
    # Safely handle expiration time
    if auth.dig(:credentials, :expires_at).present?
      user.google_expires_at =
        Time.at(auth.dig(:credentials, :expires_at)).to_datetime
    end

    # Handle Devise requirements (skip password validation for OAuth)
    user.skip_password_validation = true
    # Only set a new password if it's a completely new record with no password set
    if user.new_record? || user.encrypted_password.blank?
      user.password = Devise.friendly_token[0, 20]
      user.password_confirmation = user.password
    end

    if user.save
      user
    else
      Rails.logger.error(
        "OAuth user save failed after ID token verification: #{user.errors.full_messages.join(", ")}"
      )
      user
    end
  end

  def is_admin?
    is_admin
  end

  def self.from_google_token(id_token)
    # Class method to find or create a user from a Google ID token (for API authentication)
    begin
      verifier =
        Google::Auth::IDTokens::Verifier.new(
          aud: Rails.application.credentials.dig(:API, :google_client_id)
        )
      payload = verifier.verify(id_token)

      raise StandardError.new("Invalid Google ID token") unless payload.present?
    rescue Google::Auth::IDTokens::VerificationError,
           Google::Auth::IDTokens::SignatureError => e
      Rails.logger.error("Google ID token signature error: #{e.message}")
      return nil
    rescue => e
      Rails.logger.error("Error verifying Google ID token: #{e.message}")
      return nil
    end

    user = find_or_initialize_by(provider: "google_oauth2", uid: payload["sub"])

    user.email = payload["email"]
    user.first_name = payload["given_name"]
    user.last_name = payload["family_name"]
    user.skip_password_validation = true
    user.password = Devise.friendly_token[0, 20] if user.new_record?
    user.password_confirmation = user.password if user.new_record?

    if user.save
      user
    else
      Rails.logger.error(
        "Google token user save failed: #{user.errors.full_messages.join(", ")}"
      )
      user
    end
  end

  def first_aid_achievement_date_required
    # 1. Only proceed with the check if the user has marked 'has_first_aid_qualification' as true.
    if self.has_first_aid_qualification?
      # 2. If the qualification flag is true, but the date field is empty, add an error.
      if self.first_aid_achievement_date.blank?
        errors.add(
          :first_aid_achievement_date,
          "must be recorded if the user holds a First Aid and CPR qualification."
        )
      end
    end
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def password_is_being_changed?
    password.present? || password_confirmation.present?
  end
end