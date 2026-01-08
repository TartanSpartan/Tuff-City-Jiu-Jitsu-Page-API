require "rails_helper"

RSpec.describe User, type: :model do
  # Use `subject` to set the default instance for shoulda-matchers
  subject { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_length_of(:first_name).is_at_most(50) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(50) }

    # New test: Ensure first_name format validation is covered.
    it { expect(build(:user)).to allow_value("Valid-Name").for(:first_name) }
    it do
      expect(build(:user)).not_to allow_value("Invalid!Name").for(:first_name)
    end

    it do
      expect(build(:user)).to allow_value("Valid-Name O'Connell").for(
        :last_name
      )
    end
    it do
      expect(build(:user)).not_to allow_value("Invalid!Name").for(:last_name)
    end

    it { is_expected.to validate_presence_of(:email) }
    it { expect(build(:user)).to allow_value("valid@example.com").for(:email) }
    it { expect(build(:user)).to allow_value("VALID@EXAMPLE.COM").for(:email) }
    it { expect(build(:user)).not_to allow_value("invalid-email").for(:email) }
    it { expect(build(:user)).not_to allow_value("invalid@.com").for(:email) }

    it "is expected to validate that :email is case-insensitively unique" do
      create(:user, email: "example@domain.com")
      duplicate_user = build(:user, email: "EXAMPLE@DOMAIN.COM")
      expect(duplicate_user).to be_invalid
      expect(duplicate_user.errors[:email]).to include("is already taken")
    end

    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
    it { expect(build(:user)).to validate_confirmation_of(:password) }

    context "when from_omniauth? is false (regular user)" do
      subject { build(:user, provider: nil, uid: nil) }
      it "validates presence of password" do
        expect(subject).to validate_presence_of(:password)
      end

      it "validates presence of password_confirmation" do
        expect(subject).to validate_presence_of(:password_confirmation)
      end
    end

    context "when a regular user is being updated without changing their password" do
      let(:existing_user) { create(:user) }
      let(:new_first_name) { "NewName" }

      # New test: Ensure a regular update to a non-password field doesn't fail.
      it "does not validate password presence" do
        existing_user.first_name = new_first_name
        expect(existing_user).to be_valid
        expect(existing_user.save).to be_truthy
        expect(existing_user.reload.first_name).to eq(new_first_name)
      end
    end

    context "when from_omniauth? is true (OAuth user)" do
      let(:valid_omniauth_user) do
        build(
          :user,
          provider: "google_oauth2",
          uid: "12345",
          password: nil,
          password_confirmation: nil,
          skip_password_validation: true
        )
      end

      it "does not validate presence of password" do
        valid_omniauth_user.password = nil
        expect(valid_omniauth_user.password_required?).to be false
        expect(valid_omniauth_user).to be_valid
      end

      it "does not validate presence of password_confirmation" do
        valid_omniauth_user.password_confirmation = nil
        expect(valid_omniauth_user.password_required?).to be false
        expect(valid_omniauth_user).to be_valid
      end
    end
  end

  describe "Factory" do
    it "is valid" do
      user = FactoryBot.build(:user)
      expect(user).to be_valid
    end

    it "creates an admin user" do
      # This is the correct way to build a user with the :admin trait
      admin_user = FactoryBot.build(:user, :admin)

      expect(admin_user).to be_valid
      expect(admin_user.is_admin).to be_truthy
    end

    it "consistently generates valid users" do
      10.times do
        user = FactoryBot.build(:user)
        expect(user).to be_valid
      end
    end
  end

  describe "associations" do
    # This test verifies the `dependent: :nullify` association
    # between User and BeltGrade.
    it "nullifies associated belt grades when a user is destroyed" do
      # Create a user and an associated belt grade using FactoryBot.
      user = create(:user)
      belt_grade = create(:belt_grade, user: user)

      # Expect the User count to decrease by 1 when the user is destroyed.
      expect { user.destroy }.to change { User.count }.by(-1)

      # The key assertion: check that the belt grade record still exists
      # but its user_id has been set to nil, as per `dependent: :nullify`.
      expect(belt_grade.reload.user_id).to be_nil
    end

    it { is_expected.to have_one(:waiver).dependent(:nullify) }
    # Updated to reflect the has_many association in our model
    it do
      is_expected.to have_many(:instructor_qualifications).dependent(:nullify)
    end
    it do
      is_expected.to have_many(:qualifications).through(
        :instructor_qualifications
      )
    end

    # New test: Ensure the has_many through association is covered.
    it { is_expected.to have_many(:syllabi).through(:user_syllabi) }

    context "with waiver trait" do
      let!(:user_with_waiver) { create(:user, :with_waiver) }

      it "creates a waiver record" do
        expect(user_with_waiver.waiver).to be_present
      end

      it "does not allow a user to have more than one waiver" do
        waiver = build(:waiver, user: user_with_waiver)
        expect(waiver).not_to be_valid
      end
    end

    context "with qualification traits" do
      it "creates a user with an instructor qualification" do
        user = create(:user, :with_club_instructor_qual)
        # Updated to check the collection, not a singular object
        expect(user.instructor_qualifications).to be_present
      end

      it "creates a user with a specific qualification level" do
        user = create(:user, :with_club_instructor_qual)
        # Updated to access the first item in the collection
        expect(user.qualifications.first.level).to eq("Club instructor")
      end

      it "creates an InstructorQualification record with the correct user association" do
        user = create(:user, :with_club_instructor_qual)
        # Updated to get the first item from the collection
        instructor_qual = user.instructor_qualifications.first
        expect(instructor_qual.user).to eq(user)
      end
    end

    # New tests for user associations
    it "destroys associated user_syllabi when a user is destroyed" do
      user = create(:user)
      user_syllabus = create(:user_syllabus, user: user)
      expect { user.destroy }.to change(UserSyllabus, :count).by(-1)
      expect(UserSyllabus.find_by(id: user_syllabus.id)).to be_nil
    end

    it "nullifies associated instructor_qualifications when a user is destroyed" do
      user = create(:user)
      instructor_qual = create(:instructor_qualification, user: user)
      expect { user.destroy }.to change(User, :count).by(-1)
      expect(
        InstructorQualification.find_by(id: instructor_qual.id)
      ).to be_present
      expect(instructor_qual.reload.user_id).to be_nil
    end

    it "returns the most recent belt grade with the current_belt_grade association" do
      user = create(:user)
      old_grade = create(:belt_grade, user: user, obtained_at: 1.year.ago)
      recent_grade = create(:belt_grade, user: user, obtained_at: 1.day.ago)
      expect(user.current_belt_grade).to eq(recent_grade)
      expect(user.current_belt_grade).not_to eq(old_grade)
    end
  end

  describe "#full_name" do
    it "returns the correct full name with capitalization" do
      user = build(:user, first_name: "john", last_name: "doe")
      expect(user.full_name).to eq("John Doe")
    end
  end

  describe "#downcase_email" do
    it "saves emails in lowercase" do
      user = create(:user, email: "JOHNDOE@TEST.COM")
      expect(user.reload.email).to eq("johndoe@test.com")
    end
  end

  describe "#from_omniauth?" do
    it "returns true when from_omniauth is set to true" do
      user = build(:user, from_omniauth: true)
      expect(user.from_omniauth?).to be true
    end

    it "returns false when from_omniauth is false or nil" do
      user = build(:user, from_omniauth: false)
      expect(user.from_omniauth?).to be false
      user_nil = build(:user, from_omniauth: nil)
      expect(user_nil.from_omniauth?).to be false
    end
  end

  describe "#password_required?" do
    it "returns false when skip_password_validation is true" do
      user = build(:user, skip_password_validation: true)
      expect(user.password_required?).to be false
    end

    it "calls super when skip_password_validation is false" do
      user_requiring_password =
        build(
          :user,
          skip_password_validation: false,
          password: nil,
          password_confirmation: nil
        )
      expect(user_requiring_password.password_required?).to be true
    end

    it "calls super when skip_password_validation is nil" do
      user_requiring_password =
        build(
          :user,
          skip_password_validation: nil,
          password: nil,
          password_confirmation: nil
        )
      expect(user_requiring_password.password_required?).to be true
    end
  end

  describe "#is_admin?" do
    it "returns true if the user is an admin" do
      admin_user = build(:user, :admin)
      expect(admin_user.is_admin?).to be true
    end

    it "returns false if the user is not an admin" do
      non_admin_user = build(:user)
      expect(non_admin_user.is_admin?).to be false
    end
  end

  describe ".from_omniauth" do
    let(:auth_hash) do
      {
        provider: "google_oauth2",
        uid: "12345",
        info: {
          email: "test@google.com",
          first_name: "Test",
          last_name: "User",
          name: "Test User"
        },
        credentials: {
          token: "google_token",
          refresh_token: "google_refresh_token",
          expires_at: 1_678_886_400
        },
        extra: {
          id_token: "mock_id_token"
        }
      }
    end
    let(:verified_payload) do
      {
        "sub" => "12345",
        "email" => "test@google.com",
        "given_name" => "Test",
        "family_name" => "User"
      }
    end

    before do
      # This is the crucial line we discussed.
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_return(
        verified_payload
      )
      allow(Rails.application.credentials).to receive(:dig).with(
        :API,
        :google_client_id
      ).and_return("mock_client_id")
      allow(Rails.logger).to receive(:error)
    end

    context "when a new user signs up" do
      it "creates a new user" do
        initial_count = User.count

        user = User.from_omniauth(auth_hash)

        expect(User.count).to eq(initial_count + 1)
        expect(user).to be_persisted
      end

      it "assigns the correct attributes" do
        user = User.from_omniauth(auth_hash)
        expect(user).to be_persisted
        expect(user.email).to eq("test@google.com")
        expect(user.first_name).to eq("Test")
        expect(user.last_name).to eq("User")
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("12345")
      end

      it "sets a password and skip_password_validation flag" do
        user = User.from_omniauth(auth_hash)
        expect(user.password).to be_present
        expect(user.password_confirmation).to eq(user.password)
        expect(user.skip_password_validation).to be_truthy
      end
    end

    context "when an existing user signs in" do
      let!(:existing_user) do
        create(
          :user,
          provider: "google_oauth2",
          uid: "12345",
          email: "test@google.com"
        )
      end

      it "does not create a new user" do
        expect { User.from_omniauth(auth_hash) }.to_not change(User, :count)
      end

      it "returns the existing user" do
        user = User.from_omniauth(auth_hash)
        expect(user).to eq(existing_user)
      end

      it "updates user tokens" do
        User.from_omniauth(auth_hash)
        existing_user.reload
        expect(existing_user.google_token).to eq("google_token")
        expect(existing_user.google_refresh_token).to eq("google_refresh_token")
      end
    end

    context "when ID token verification fails" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_raise(
          Google::Auth::IDTokens::VerificationError.new("Invalid token")
        )
      end
      it "returns nil" do
        expect(User.from_omniauth(auth_hash)).to be_nil
      end
      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /Google ID token verification failed: Invalid token/
        )
        User.from_omniauth(auth_hash)
      end
    end

    context "when the ID token is missing from the auth hash" do
      let(:invalid_auth_hash) do
        auth_hash.deep_dup.tap { |h| h[:extra].delete(:id_token) }
      end
      it "returns nil" do
        expect(User.from_omniauth(invalid_auth_hash)).to be_nil
      end
      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /Google ID token is missing in the OmniAuth hash./
        )
        User.from_omniauth(invalid_auth_hash)
      end
    end

    context "when saving a new user fails" do
      before do
        allow_any_instance_of(User).to receive(:save).and_return(false)
        mock_errors = instance_double(ActiveModel::Errors)
        allow(mock_errors).to receive(:full_messages).and_return(
          ["Save failed"]
        )
        allow_any_instance_of(User).to receive(:errors).and_return(mock_errors)
      end
      it "returns the user object with errors" do
        user = User.from_omniauth(auth_hash)
        expect(user).to be_a(User)
        expect(user.persisted?).to be false
        expect(user.errors.full_messages).to include("Save failed")
      end
      it "logs the save failure" do
        expect(Rails.logger).to receive(:error).with(
          /OAuth user save failed after ID token verification: Save failed/
        )
        User.from_omniauth(auth_hash)
      end
    end
  end

  describe ".from_google_token" do
    let(:valid_google_id_token) { "valid_id_token" }
    let(:verified_payload) do
      {
        "sub" => "mock_uid_67890",
        "email" => "tokenuser@example.com",
        "given_name" => "Token",
        "family_name" => "User"
      }
    end

    before do
      allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
        :verify
      ).and_return(verified_payload)
      allow(Rails.application.credentials).to receive(:dig).with(
        :API,
        :google_client_id
      ).and_return("mock_client_id")
      allow(Rails.logger).to receive(:error)
    end

    context "when a user with the provider and uid already exists" do
      let!(:existing_user) do
        create(
          :user,
          provider: "google_oauth2",
          uid: "mock_uid_67890",
          email: "existing.token@example.com"
        )
      end

      it "finds and returns the existing user" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to eq(existing_user)
        expect(user).not_to be_new_record
      end

      it "saves the user" do
        expect_any_instance_of(User).to receive(:save).and_call_original
        User.from_google_token(valid_google_id_token)
      end
    end

    context "when a user with the provider and uid does not exist" do
      it "creates a new user" do
        expect { User.from_google_token(valid_google_id_token) }.to change(
          User,
          :count
        ).by(1)

        # touch User.last to ensure persistence without unused variable warnings
        expect(User.last).to be_present
      end

      it "assigns the correct attributes to the new user" do
        user = User.from_google_token(valid_google_id_token)

        expect(user).to be_persisted
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("mock_uid_67890")
        expect(user.email).to eq("tokenuser@example.com")
        expect(user.first_name).to eq("Token")
        expect(user.last_name).to eq("User")
        expect(user.password).to be_present
      end

      it "saves and returns the new user" do
        user = User.from_google_token(valid_google_id_token)

        expect(user).to be_persisted
        expect(user).to be_a(User)
      end
    end

    context "when the Google client ID is missing in credentials" do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(
          :API,
          :google_client_id
        ).and_return(nil)
        allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
          :verify
        ).and_raise(StandardError.new("Audience must be configured"))
      end
      it "returns nil" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to be_nil
      end
      it "logs an error" do
        expect(Rails.logger).to receive(:error).with(
          /Error verifying Google ID token: Audience must be configured/
        )
        User.from_google_token(valid_google_id_token)
      end
    end

    context "when ID token verification fails" do
      before do
        allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
          :verify
        ).and_raise(
          Google::Auth::IDTokens::SignatureError.new("Invalid signature")
        )
      end
      it "returns nil" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to be_nil
      end
      it "logs an error" do
        expect(Rails.logger).to receive(:error).with(
          /Google ID token signature error: Invalid signature/
        )
        User.from_google_token(valid_google_id_token)
      end
    end

    context "when ID token verification returns nil payload" do
      before do
        allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
          :verify
        ).and_return(nil)
      end
      it "returns nil" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to be_nil
      end
      it "logs an error" do
        expect(Rails.logger).to receive(:error).with(/Invalid Google ID token/)
        User.from_google_token(valid_google_id_token)
      end
    end

    context "when saving the new user fails" do
      before do
        allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
          :verify
        ).and_return(verified_payload)
        allow(User).to receive(:find_or_initialize_by).and_call_original
        allow_any_instance_of(User).to receive(:save).and_return(false)
        mock_errors = instance_double(ActiveModel::Errors)
        allow(mock_errors).to receive(:full_messages).and_return(
          ["Save failed"]
        )
        allow_any_instance_of(User).to receive(:errors).and_return(mock_errors)
      end

      it "returns the user object (with errors)" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to be_a(User)
        expect(user).not_to be_persisted
        expect(user.errors).to be_present
        expect(user.errors.full_messages).to include("Save failed")
      end
    end

    context "when an unexpected error occurs during the process" do
      before do
        allow_any_instance_of(Google::Auth::IDTokens::Verifier).to receive(
          :verify
        ).and_raise(StandardError.new("Some unexpected token error"))
      end
      it "returns nil" do
        user = User.from_google_token(valid_google_id_token)
        expect(user).to be_nil
      end
      it "logs an error" do
        expect(Rails.logger).to receive(:error).with(
          /Error verifying Google ID token: Some unexpected token error/
        )
        User.from_google_token(valid_google_id_token)
      end
    end
  end
end
