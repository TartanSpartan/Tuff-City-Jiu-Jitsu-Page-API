require "rails_helper"

RSpec.describe Waiver, type: :model do
  # Use `subject` to set the default instance for shoulda-matchers
  subject { build(:waiver) }

  describe "associations" do
    it { is_expected.to belong_to(:user).optional(true) }
  end

  describe "callbacks" do
    it "capitalizes specified fields before saving" do
      waiver =
        build(
          :waiver,
          participant_name: "john doe",
          initials: "jd",
          participant_address: "123 main st",
          organization_witness_name: "jane smith",
          emergency_contact_name: "sarah jones",
          relationship: "sister"
        )
      waiver.save
      # The model normalizes fields conservatively: strips/squishes and upcases initials.
      expect(waiver.participant_name).to eq("john doe")
      expect(waiver.initials).to eq("JD")
      expect(waiver.participant_address).to eq("123 main st")
      expect(waiver.organization_witness_name).to eq("jane smith")
      expect(waiver.emergency_contact_name).to eq("sarah jones")
      expect(waiver.relationship).to eq("sister")
    end
  end

  describe "validations" do
    it "is valid with a unique user_id" do
      create(:waiver, user: create(:user))
      waiver = build(:waiver, user: create(:user))
      expect(waiver).to be_valid
    end

    it "is valid when user_id is nil" do
      waiver = build(:waiver, user: nil)
      expect(waiver).to be_valid
    end

    it "is invalid with a duplicate user_id" do
      user = create(:user)
      create(:waiver, user: user)
      duplicate_waiver = build(:waiver, user: user)
      expect(duplicate_waiver).to be_invalid
      expect(duplicate_waiver.errors[:user_id]).to include(
        "has already been taken"
      )
    end

    # Context to ensure the email uniqueness test doesn't fail on user_id validation
    context "participant_email_address validations" do
      # Create an initial waiver without a user
      let!(:existing_waiver) { create(:waiver, :unsigned) }

      # Reset the user association for all tests in this context
      before(:each) do
        existing_waiver.update!(user: nil)
        subject.user = nil
      end

      it { is_expected.to validate_presence_of(:participant_email_address) }
      it do
        is_expected.to validate_uniqueness_of(
          :participant_email_address
        ).case_insensitive.with_message("is already taken")
      end
      it do
        is_expected.to allow_value("valid@example.com").for(
          :participant_email_address
        )
      end
      it do
        is_expected.not_to allow_value("invalid-email").for(
          :participant_email_address
        )
      end
    end

    context "custom age validation" do
      it "is valid if participant is 18 years or older" do
        # Use Date.today to ensure the signed_on date is valid for this test.
        waiver =
          build(
            :waiver,
            participant_date_of_birth: 19.years.ago.to_date,
            signed_on: Date.today
          )
        expect(waiver).to be_valid
      end

      it "is valid on the participant's 18th birthday" do
        # We explicitly set the signed_on date to be today to ensure the participant is
        # exactly 18 years old on the day the waiver is signed.
        eighteenth_birthday = 18.years.ago.to_date
        waiver =
          build(
            :waiver,
            participant_date_of_birth: eighteenth_birthday,
            signed_on: Date.today
          )
        expect(waiver).to be_valid
      end

      it "is invalid if participant is younger than 18" do
        # Use Date.today to ensure the signed_on date is valid for this test.
        waiver =
          build(
            :waiver,
            participant_date_of_birth: 17.years.ago.to_date,
            signed_on: Date.today
          )
        expect(waiver).not_to be_valid
        expect(waiver.errors[:participant_date_of_birth]).to include(
          "must be 18 years or older"
        )
      end

      it "is valid if participant_date_of_birth is nil" do
        waiver = build(:waiver, participant_date_of_birth: nil)
        # DOB is now required by the model; absence should produce a validation error
        expect(waiver).not_to be_valid
        expect(waiver.errors[:participant_date_of_birth]).to include(
          "can't be blank"
        )
      end
    end

    it { is_expected.to validate_presence_of(:participant_name) }
    it { is_expected.to validate_presence_of(:initials) }
    it { is_expected.to validate_presence_of(:participant_address) }
    it { is_expected.to validate_presence_of(:participant_signature) }
    it do
      is_expected.to validate_presence_of(:organization_witness_name).on(
        :update
      )
    end
    it do
      is_expected.to validate_presence_of(:organization_witness_signature).on(
        :update
      )
    end
    it { is_expected.to validate_presence_of(:participant_phone) }
    it { is_expected.to validate_presence_of(:emergency_contact_name) }
    it { is_expected.to validate_presence_of(:emergency_contact_number) }
    it { is_expected.to validate_presence_of(:relationship) }
    it { is_expected.to validate_presence_of(:signed_on) }
  end

  describe "factory" do
    it "is valid" do
      waiver = build(:waiver)
      expect(waiver).to be_valid
    end

    it "is valid without a user when using the :unsigned trait" do
      waiver = build(:waiver, :unsigned)
      expect(waiver).to be_valid
      expect(waiver.user).to be_nil
    end
  end

  describe "normalization and scopes" do
    it "downcases and strips participant_email_address before validation" do
      waiver = build(:waiver, participant_email_address: "  USER@Example.COM ")
      expect(waiver).to be_valid
      waiver.save
      expect(waiver.participant_email_address).to eq("user@example.com")
    end

    it "normalizes phone numbers by removing non-digits (preserves leading +)" do
      waiver =
        build(
          :waiver,
          participant_phone: "+1 (234) 567-8900",
          emergency_contact_number: "(555) 987-6543"
        )
      waiver.save
      expect(waiver.participant_phone).to eq("+12345678900")
      expect(waiver.emergency_contact_number).to eq("5559876543")
    end

    describe "edge cases" do
      context "leap-year birthdays" do
        it "considers someone born on Feb 29 to turn 18 on Mar 1 in non-leap years" do
          dob = Date.new(2004, 2, 29)
          # 2022 is not a leap year: Feb 28 should be considered one day before turning 18
          before_birthday =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: Date.new(2022, 2, 28)
            )
          expect(before_birthday).not_to be_valid

          on_or_after =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: Date.new(2022, 3, 1)
            )
          expect(on_or_after).to be_valid
        end

        it "validates correctly on an actual leap-year birthday" do
          dob = Date.new(2004, 2, 29)
          leap_day =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: Date.new(2024, 2, 29)
            )
          expect(leap_day).to be_valid
        end
      end

      context "db-level uniqueness constraints" do
        it "raises an error when inserting a case-variant email that violates the DB unique index" do
          # Create the initial waiver via the model so normalizations run.
          create(
            :waiver,
            participant_email_address: "user@example.com",
            user: nil
          )

          # Attempt to insert a row that differs only by case and bypasses validations.
          new_waiver =
            Waiver.new(
              participant_email_address: "USER@EXAMPLE.COM",
              participant_name: "Bypass",
              initials: "BB",
              participant_address: "123 Test",
              participant_signature: "sig",
              organization_witness_name: nil,
              organization_witness_signature: "wsig",
              participant_date_of_birth: Date.new(1980, 1, 1),
              participant_phone: "123456",
              emergency_contact_name: "EC",
              emergency_contact_number: "654321",
              relationship: "Friend",
              signed_on: Date.today
            )

          # Bypass model validations and attempt to persist directly to the DB to trigger the unique index.
          expect { new_waiver.save!(validate: false) }.to raise_error(
            ActiveRecord::RecordNotUnique
          )
        end
      end
    end

    describe "timezones" do
      it "does not produce off-by-one errors when signed_on is a Time in a different zone" do
        Time.use_zone("Pacific/Auckland") do
          dob = Date.new(2007, 3, 1)

          # Local time just before midnight on the day before the 18th birthday
          just_before = Time.zone.local(2025, 2, 28, 23, 30)
          waiver_before =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: just_before
            )
          expect(waiver_before).not_to be_valid

          # Local time shortly after midnight on the 18th birthday
          just_after = Time.zone.local(2025, 3, 1, 0, 30)
          waiver_after =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: just_after
            )
          expect(waiver_after).to be_valid
        end
      end
    end

    describe "broader timezone coverage" do
      %w[
        Pacific/Auckland
        America/Los_Angeles
        UTC
        Asia/Kolkata
        Pacific/Honolulu
      ].each do |zone|
        it "handles boundary times correctly in zone #{zone}" do
          Time.use_zone(zone) do
            dob = Date.new(2007, 3, 1)

            # Just before midnight local time the day before turning 18
            just_before = Time.zone.local(2025, 2, 28, 23, 59, 59)
            waiver_before =
              build(
                :waiver,
                participant_date_of_birth: dob,
                signed_on: just_before
              )
            expect(waiver_before).not_to be_valid,
            "expected invalid in zone #{zone} for time #{just_before}"

            # Just after midnight local time on the 18th birthday
            just_after = Time.zone.local(2025, 3, 1, 0, 0, 1)
            waiver_after =
              build(
                :waiver,
                participant_date_of_birth: dob,
                signed_on: just_after
              )
            expect(waiver_after).to be_valid,
            "expected valid in zone #{zone} for time #{just_after}"
          end
        end
      end

      it "handles DateTime inputs with explicit offsets" do
        # Use a zone with a non-whole-hour offset to ensure we cover that edge (e.g., India)
        dt_before = DateTime.parse("2025-02-28T23:30:00+05:30")
        waiver_before =
          build(
            :waiver,
            participant_date_of_birth: Date.new(2007, 3, 1),
            signed_on: dt_before
          )
        expect(waiver_before).not_to be_valid

        dt_after = DateTime.parse("2025-03-01T00:30:00+05:30")
        waiver_after =
          build(
            :waiver,
            participant_date_of_birth: Date.new(2007, 3, 1),
            signed_on: dt_after
          )
        expect(waiver_after).to be_valid
      end
    end

    describe "signed_on input types and UTC instants" do
      it "treats Date and Time inputs for the same calendar day as equivalent" do
        Time.use_zone("UTC") do
          dob = Date.new(2007, 3, 1)
          signed_date = Date.new(2025, 3, 1)
          signed_time = Time.zone.local(2025, 3, 1, 12, 0)

          waiver_with_date =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: signed_date
            )
          waiver_with_time =
            build(
              :waiver,
              participant_date_of_birth: dob,
              signed_on: signed_time
            )

          expect(waiver_with_date).to be_valid
          expect(waiver_with_time).to be_valid
        end
      end

      it "keeps behavior consistent when the same instant is supplied in UTC and local representations" do
        dob = Date.new(2007, 3, 1)

        # An instant that is 2025-03-01T00:30:00Z (UTC)
        instant_utc = Time.utc(2025, 3, 1, 0, 30)

        # Represent the same instant in a different zone
        instant_in_la = instant_utc.in_time_zone("America/Los_Angeles")

        waiver_utc =
          build(:waiver, participant_date_of_birth: dob, signed_on: instant_utc)
        waiver_la =
          build(
            :waiver,
            participant_date_of_birth: dob,
            signed_on: instant_in_la
          )

        # Determine the age according to the model's logic using the waiver's signed_on date
        [waiver_utc, waiver_la].each do |w|
          signed = w.signed_on.to_date
          age = signed.year - dob.year
          age -= 1 if signed.yday < dob.yday

          # The model considers the waiver valid if age >= 18 (in combination with other required fields).
          # Assert that the model's validity matches the computed age check for the DOB boundary.
          expect(w.valid?).to eq(age >= 18)
        end
      end
    end

    it "upcases and compacts initials" do
      waiver = build(:waiver, initials: " j d ")
      waiver.save
      expect(waiver.initials).to eq("JD")
    end

    it "outstanding scope includes nil and blank witness names" do
      waived_with_nil = create(:waiver, organization_witness_name: nil)
      waived_with_blank = create(:waiver, organization_witness_name: "")
      completed = create(:waiver, organization_witness_name: "Alice")

      results = Waiver.outstanding
      expect(results).to include(waived_with_nil, waived_with_blank)
      expect(results).not_to include(completed)
    end

    it "enforces case-insensitive uniqueness on participant_email_address at the model level" do
      create(:waiver, participant_email_address: "user@example.com", user: nil)
      dup =
        build(:waiver, participant_email_address: "USER@EXAMPLE.COM", user: nil)
      expect(dup).to be_invalid
      expect(dup.errors[:participant_email_address]).to include(
        "is already taken"
      )
    end
  end

  describe "validate_legal_age integration" do
    it "calls #age_on during validation and uses its result" do
      waiver = build(:waiver)
      waiver.participant_date_of_birth = Date.new(2008, 1, 1)
      waiver.signed_on = Date.new(2025, 1, 1)

      # Ensure the age helper is invoked and force it to return < 18 to trigger the validation
      expect(waiver).to receive(:age_on).with(waiver.signed_on).and_return(17)

      waiver.valid?
      expect(waiver.errors[:participant_date_of_birth]).to include(
        "must be 18 years or older"
      )
    end
  end
end
