require "rails_helper"

RSpec.describe SyllabusPresenter do
  describe "#as_jsonapi" do
    it "builds data and included arrays with belts, technique_types and techniques" do
      t = double("technique", id: 101, summary: "sum1")
      tt = double("technique_type", id: 11, category: "cat", sub_category: "sub", techniques: [t])
      belt = double(
        "belt",
        id: 1,
        kyu_number: 3,
        colour: "white",
        created_at: Time.now,
        updated_at: Time.now,
        syllabus_id: 7,
        technique_types: [tt]
      )

      syllabus = double("syllabus", id: 7, country: "UK", year: 2020, visible_belts_for: [belt])

      presenter = described_class.new(syllabus, double("user"))
      payload = presenter.as_jsonapi

      expect(payload).to be_a(Hash)
      expect(payload[:data][:type]).to eq("syllabi")
      expect(payload[:data][:relationships][:belts][:data]).to include({ type: "belts", id: "1" })
      expect(payload[:included]).to be_an(Array)
      types = payload[:included].map { |i| i[:type] }.uniq
      expect(types).to include("belts", "technique_types", "techniques")
    end
  end
end
