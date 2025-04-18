require 'googleauth'
require 'googleauth/id_tokens'
# puts "--- User Model Loaded ---"

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2] 
        #  , :provider_ignores_state => true # This is a debug test setting for google_oauth2

  has_one :waiver, dependent: :nullify # We will retain user waivers even if they delete their accounts, for record keeping purposes as they may wish to continue training, so closing a user account does not result in waiver deletion
  # has_many :posts, dependent: :nullify # note: uncomment when/if posts are added to the website
  # has_many :comments, dependent: :nullify # note: uncomment when/if comments are added to the website
  has_one :syllabus, dependent: :nullify
  has_one :instructor_qualification, dependent: :nullify
  has_one :belt_grade, dependent: :nullify
  # has_secure_password

  attr_accessor :from_omniauth
  before_save :downcase_email

  # Do not need to validate belt_grade_id, qualifications_id as this is configurable only by admins or instructors
  # And these can be further constrained to sane input using dropdown menus and no other means of input
  validates :first_name, :last_name, presence: true, length: { maximum: 50 }, format: { with: /\A[\p{L}\p{M}\p{Pd}ʼ’‘\- ]+\z/, message: "only allows letters and associated accents, diacritics, punctuation, etc"}
  # validates :email, presence: true, uniqueness:  { case_sensitive: false }, 
  # format: { with: /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i }
  # validates :email, 
  #           format: { with: URI::MailTo::EMAIL_REGEXP, message: "invalid email format" }, 
  #           uniqueness: { case_sensitive: false, message: "is already taken by another user" }
  validates :email, presence: true, 
            uniqueness: { case_sensitive: false, message: "is already taken" }, 
            format: { with: /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i, message: "invalid email format" }

  # Compare the three above validations, second is worst, third may be best
  # There may be some edge cases with symbols like plus signs, how would we handle these?

  validates :password, presence: true, length: { minimum: 8 }, confirmation: true, unless: :from_omniauth?
  validates :password_confirmation, presence: true, unless: :from_omniauth?
  # TODO: Add special characters check, here and in the client

  def full_name
    "#{first_name.titleize} #{last_name.titleize}".strip
    # Titleize helps with edge cases with mixed capitalization like FitzGerald
  end

  def self.from_omniauth(auth_hash)
    require 'googleauth/id_tokens'
    begin

      id_token = auth_hash&.dig('extra', 'id_token')

      if id_token.blank?
        Rails.logger.error "Google ID token is missing in the OmniAuth hash."
        return nil
      end

      client_id = Rails.application.credentials.dig(:API, :google_client_id)

      if client_id.blank?
        Rails.logger.error "GOOGLE_CLIENT_ID environment variable not set."
        return nil
      end

      # jwks_url = 'https://www.googleapis.com/oauth2/v1/certs' # Or try 'https://www.googleapis.com/oauth2/v3/certs'
      # jwks = Google::Auth::IDTokens::Verifier.new(jwks_url).fetch_jwks
      # # verifier = Google::Auth::IDTokens::Verifier.
      # verifier = Google::Auth::IDTokens::Verifier.new(iss: 'https://accounts.google.com')
      # # validator = Google::Auth::IDTokens::Verifier.new(aud: client_id)
      # # payload = validator.verify(id_token)
      # payload = verifier.verify(id_token, jwks, audience: [client_id])

      # key_source = Google::Auth::IDTokens::JwkHttpKeySource.new(Google::Auth::IDTokens::OAUTH2_V3_CERTS_URL)
      # verifier = Google::Auth::IDTokens::Verifier.new(key_source: key_source)
      # # Assuming 'token' is the Google ID token received
      # payload = verifier.verify(token)

      payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: client_id)

      if payload
        provider = auth_hash[:provider]
        uid = payload['sub'] # Use sub from the verified payload
        info = auth_hash[:info] # Keep using info from auth_hash for consistency with Devise
        credentials = auth_hash[:credentials]

        # Ensure email is present in the payload (it should be)
        email = payload['email']
        if email.blank?
          Rails.logger.error "Email is missing from the verified Google ID token payload."
          return nil
        end

        user = User.find_or_initialize_by(provider: provider, uid: uid)

        if user.new_record?
          user.email = email
          user.first_name = payload['given_name'] || auth.info.first_name.presence || auth.info.name&.split&.first.presence || "First Name"
          user.last_name = payload['family_name'] || auth.info.last_name.presence || auth.info.name&.split&.last.presence || "Last Name"
          user.skip_password_validation = true
          user.password = Devise.friendly_token[0, 20]
          user.password_confirmation = user.password
        end

        # Store tokens
        if credentials
          user.google_token = credentials[:token]
          user.google_refresh_token ||= credentials[:refresh_token] # Prevent overwriting valid token
          user.google_expires_at = Time.at(credentials[:expires_at]) if credentials[:expires_at]
        end
        if user.save
          Rails.logger.info("User successfully saved via OAuth (verified ID token): #{user.email}")
        else
          Rails.logger.error("OAuth user save failed after ID token verification: #{user.errors.full_messages}")
        end

        user # Return user
      else
        Rails.logger.error "Google ID token verification failed."
        return nil
      end

rescue Google::Auth::IDTokens::VerificationError => e
  Rails.logger.error "Google ID token verification failed: #{e.message}"
  return nil
rescue Google::Auth::IDTokens::SignatureError => e
  Rails.logger.error "Google ID token signature error: #{e.message}"
  return nil
rescue StandardError => e
  Rails.logger.error "Error verifying Google ID token: #{e.message}"
  Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
  return nil # Or handle the error as appropriate
rescue Google::Auth::IDTokens::AudienceMismatchError => e
  Rails.logger.error "Google ID token audience mismatch: #{e.message}"
  return nil
rescue Google::Auth::IDTokens::IssuerMismatchError => e
  Rails.logger.error "Google ID token issuer mismatch: #{e.message}"
  return nil
rescue Google::Auth::IDTokens::KeySourceError => e
  Rails.logger.error "Error fetching Google ID token verification keys: #{e.message}"
  return nil
end
  end

  def from_omniauth?
    provider.present? && uid.present? # Or check for the flag we set in from_omniauth
  end

  def password_required?
    return false if skip_password_validation
    super
  end

  attr_accessor :skip_password_validation

  def self.from_google_token(google_id_token)
    begin
      client_id = Rails.application.credentials.dig(:API, :google_client_id)
      validator = Google::Auth::IDTokens::Verifier.new(aud: client_id)
      payload = validator.verify(google_id_token)

      if payload
        email = payload['email']
        given_name = payload['given_name']
        family_name = payload['family_name']
        google_uid = payload['sub'] # Google's unique user ID

        # Reuse the find_or_create logic from from_omniauth
        user = User.find_or_initialize_by(provider: 'google_oauth2', uid: google_uid) do |u|
          u.email = email
          u.first_name = given_name
          u.last_name = family_name
          u.password = Devise.friendly_token[0, 20] # Set a default password for the user in the case of Google signup
        end

        user.save
        user
      else
        Rails.logger.error "Invalid Google ID token"
        nil
      end
    rescue Google::Auth::IDTokens::SignatureError => e
      Rails.logger.error "Google ID token signature error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Error verifying Google ID token: #{e.message}"
      nil
    end
  end

  # def self.from_omniauth_old(auth)

  #   # TODO check this in the tester file
  #   begin
  #     # Check for missing info (important!)
  #     if auth.info.nil? || auth.info.email.nil?
  #       Rails.logger.error("Google Auth Error: Missing email information from auth data: #{auth.inspect}")
  #       return nil # Authentication failed
  #     end

  #     # Set first_name and last_name, with a fallback if necessary
  #     user = where(email: auth.info.email.downcase).first_or_initialize do |user|
  #       user.first_name = auth.info.first_name.presence || auth.info.name&.split&.first.presence || "First Name"
  #       user.last_name = auth.info.last_name.presence || auth.info.name&.split&.last.presence || "Last Name"
  #       user.email = auth.info.email.downcase
  #     end
  
  #     # Persist the user (important!)
  #     if user.new_record? && user.save # Only save if it's a new user
  #       Rails.logger.info("New user created via Google Auth: #{user.inspect}")
  #     elsif user.changed? && user.save
  #       Rails.logger.info("Existing user updated via Google Auth: #{user.inspect}")
  #     end
  
  #     user # Return the user object
  
  #   rescue => e # Rescue any exception
  #     Rails.logger.error("Google Auth Error: #{e.message}\n#{e.backtrace.join("\n")}")
  #     nil # Authentication failed
  #   end
  # end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end
end