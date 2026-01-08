require "rails_helper"

RSpec.describe Syllabus, type: :model do
  describe "#visible_belts_for" do
    let(:syllabus) { create(:syllabus, :with_belts) }

    def belt_for(colour)
      syllabus.belts.find { |b| b.colour.casecmp(colour).zero? }
    end

    it "returns the public default belts when user is nil" do
      belts = syllabus.visible_belts_for(nil)
      kyu_numbers = belts.map(&:kyu_number)
      expect(kyu_numbers).to eq([Syllabus::FIRST_VIEWABLE_BELT_KYU])
    end

    it "returns the expected kyu range for a user with Orange belt (kyu 6)" do
      user = create(:user)
      orange = belt_for("Orange")
      expect(orange).to be_present

      create(:belt_grade, user: user, belt: orange, obtained_at: Date.current)

      belts = syllabus.visible_belts_for(user)
      expect(belts.map(&:kyu_number)).to eq([5, 6, 7])
    end

    it "chooses the most recent belt_grade when multiple exist" do
      user = create(:user)
      green = belt_for("Green")
      orange = belt_for("Orange")

      # older green, newer orange -> should use orange (kyu 6) and return 5..7
      create(:belt_grade, user: user, belt: green, obtained_at: 2.years.ago)
      create(:belt_grade, user: user, belt: orange, obtained_at: Date.current)

      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        [5, 6, 7]
      )
    end

    it "returns default visible belt when user has no belt_grades" do
      user = create(:user)
      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        [Syllabus::FIRST_VIEWABLE_BELT_KYU]
      )
    end

    it "ignores belt_grades from other syllabi" do
      user = create(:user)
      other = create(:syllabus, :with_belts)
      other_orange = other.belts.find { |b| b.colour.casecmp("Orange").zero? }
      create(
        :belt_grade,
        user: user,
        belt: other_orange,
        obtained_at: Date.current
      )

      # The grade is for a different syllabus so the current syllabus should fall back to default
      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        [Syllabus::FIRST_VIEWABLE_BELT_KYU]
      )
    end

    it "treats a belt with nil kyu_number as if the user has no grade (fallback)" do
      user = create(:user)
      orange = belt_for("Orange")
      create(:belt_grade, user: user, belt: orange, obtained_at: Date.current)

      # Simulate corrupted data: remove the belt kyu_number at DB level
      orange.update_column(:kyu_number, nil)

      # Fallback behavior: act as if no grade exists -> default visible belt
      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        [Syllabus::FIRST_VIEWABLE_BELT_KYU]
      )
    end

    it "shows full range 1..7 for a Brown belt (kyu 1)" do
      user = create(:user)
      brown = belt_for("Brown")
      # Brown belt grading requires club instructor qualification and first aid in this domain model.
      # Use update_columns to bypass model validations for the test seed data (we assert behavior only).
      user.update_columns(
        has_first_aid_qualification: true,
        first_aid_achievement_date: Date.current,
        first_aid_expiry_date: Date.current + 2.years
      )
      club_q = create(:qualification, :club_instructor)
      create(
        :instructor_qualification,
        user: user,
        qualification: club_q,
        belt: brown,
        achieved_at: Date.current
      )

      # Create a user with required first-aid fields so validations pass.
      user =
        create(
          :user,
          has_first_aid_qualification: true,
          first_aid_achievement_date: Date.current,
          first_aid_expiry_date: Date.current + 2.years
        )

      # Simulate that the user's most recent belt_grade is Brown without creating the DB records.
      # Stubbing the association chain avoids invoking factories that seed base qualification IDs
      # and keeps this test focused on the selection logic in `visible_belts_for`.
      allow(user).to receive_message_chain(
        :belt_grades,
        :joins,
        :where,
        :order,
        :first
      ).and_return(double(belt: brown))

      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        (1..Syllabus::FIRST_VIEWABLE_BELT_KYU).to_a
      )
    end

    it "prefers the most recent belt_grade even if it is in the future" do
      user = create(:user)
      green = belt_for("Green")
      orange = belt_for("Orange")

      create(:belt_grade, user: user, belt: green, obtained_at: 1.year.ago)
      create(
        :belt_grade,
        user: user,
        belt: orange,
        obtained_at: 1.year.from_now
      )

      # The future orange should be considered the most recent
      expect(syllabus.visible_belts_for(user).map(&:kyu_number)).to eq(
        [5, 6, 7]
      )
    end

    it "returns an ActiveRecord::Relation so callers can chain scopes" do
      user = create(:user)
      expect(syllabus.visible_belts_for(user)).to be_a(ActiveRecord::Relation)
    end

    it "returns empty relation when syllabus has no belts" do
      empty = create(:syllabus)
      user = create(:user)
      expect(empty.visible_belts_for(user)).to be_empty
    end
  end
end
