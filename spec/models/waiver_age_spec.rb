require 'rails_helper'

RSpec.describe Waiver, type: :model do
  describe '#age_on' do
    it 'calculates age using calendar days for a normal birthday' do
      waiver = build(:waiver)
      waiver.participant_date_of_birth = Date.new(2000, 6, 15)

      expect(waiver.age_on(Date.new(2018, 6, 14))).to eq(17)
      expect(waiver.age_on(Date.new(2018, 6, 15))).to eq(18)
      expect(waiver.age_on(Time.zone.local(2018, 6, 15, 12, 0))).to eq(18)
    end

    context 'leap-year birthdays (Feb 29)' do
      it 'treats Mar 1 in non-leap years as the 18th birthday' do
        waiver = build(:waiver)
        waiver.participant_date_of_birth = Date.new(2004, 2, 29)

        # 2022 is not a leap year; 18th birthday should be Mar 1, 2022
        expect(waiver.age_on(Date.new(2022, 2, 28))).to eq(17)
        expect(waiver.age_on(Date.new(2022, 3, 1))).to eq(18)
      end

      it 'validates correctly on an actual leap-year birthday' do
        waiver = build(:waiver)
        waiver.participant_date_of_birth = Date.new(2004, 2, 29)

        expect(waiver.age_on(Date.new(2024, 2, 29))).to eq(20)
      end

      it 'handles times with time zones correctly' do
        waiver = build(:waiver)
        waiver.participant_date_of_birth = Date.new(2004, 2, 29)

        Time.use_zone('Asia/Kolkata') do
          just_before = Time.zone.local(2022, 2, 28, 23, 30)
          just_after = Time.zone.local(2022, 3, 1, 0, 30)

          expect(waiver.age_on(just_before)).to eq(17)
          expect(waiver.age_on(just_after)).to eq(18)
        end
      end
    end

    it 'returns nil if dob or at are missing' do
      waiver = build(:waiver)
      expect(waiver.age_on(nil)).to be_nil

      waiver.participant_date_of_birth = nil
      expect(waiver.age_on(Date.today)).to be_nil
    end
  end
end
