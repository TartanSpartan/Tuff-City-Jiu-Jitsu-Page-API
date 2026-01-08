require "rails_helper"

RSpec.describe SyllabusLimitedSerializer, type: :serializer do
  let(:user) { create(:user, owns_gi: true) }
  let(:syllabus) { create(:syllabus, :with_belts) }

  # Helper to find a belt by colour within the created syllabus
  def belt_for(colour)
    syllabus.belts.find { |b| b.colour.casecmp(colour).zero? }
  end

  it "serializes limited syllabus fields and filters belts based on user's current kyu (one above) through Yellow" do
    # Given the user currently holds Orange (kyu 6) for this syllabus
    orange_belt = belt_for("Orange")
    expect(orange_belt).to be_present

    create(
      :belt_grade,
      user: user,
      belt: orange_belt,
      obtained_at: Date.current
    )

    # Serialize with scope containing the current user
    json_api =
      serialize_json_api(
        described_class.new(syllabus, scope: { current_user: user }),
        includes: ["belts", "belts.technique_types", "belts.techniques"]
      )

    # Top-level JSON:API shape
    expect(json_api["data"]["id"]).to eq(syllabus.id.to_s)
    expect(json_api["data"]["type"]).to eq("syllabi")

    data = json_api["data"]
    expect(data["attributes"]["country"]).to eq(syllabus.country)
    expect(data["attributes"]["year"]).to eq(syllabus.year)

    # Belts are now a relationship; ensure linkage exists
    rels = data["relationships"]
    expect(rels).to have_key("belts")
    belts_linkage = rels["belts"]["data"]
    expect(belts_linkage).to be_an(Array)

    # Full belt attributes should appear in the top-level included array
    included = json_api["included"] || []
    belt_included = included.select { |i| i["type"] == "belts" }
    kyu_numbers = belt_included.map { |b| b["attributes"]["kyu_number"] }
    expect(kyu_numbers).to match_array([5, 6, 7])

    # Ensure each included belt item includes expected attributes via BeltSerializer
    belt_attr_keys = belt_included.first["attributes"].keys.map(&:to_s)
    expect(belt_attr_keys).to include(
      "colour",
      "kyu_number",
      "effective_kyu_grade",
      "syllabus_id",
      "created_at",
      "updated_at"
    )
  end

  it "returns only the public Yellow belt when scope has no current_user" do
    # Serialize without providing a current_user in scope
    json_api = serialize_json_api(described_class.new(syllabus, scope: {}), includes: ["belts"]) 

    # No current_user -> relationship exists but included contains only public belt
    belts_linkage = json_api["data"]["relationships"]["belts"]["data"]
    included = json_api["included"] || []
    belt_included = included.select { |i| i["type"] == "belts" }
    kyu_numbers = belt_included.map { |b| b["attributes"]["kyu_number"] }
    expect(kyu_numbers).to eq([SyllabusLimitedSerializer::FIRST_VIEWABLE_BELT_KYU])
  end

  it "preserves ascending kyu_number ordering in the belts collection" do
    orange_belt = belt_for("Orange")
    create(
      :belt_grade,
      user: user,
      belt: orange_belt,
      obtained_at: Date.current
    )

    json_api =
      serialize_json_api(
        described_class.new(syllabus, scope: { current_user: user }),
        includes: ["belts"]
      )

    belts_linkage = json_api["data"]["relationships"]["belts"]["data"]
    included = json_api["included"] || []
    belt_included = included.select { |i| i["type"] == "belts" }
    kyu_numbers = belt_included.map { |b| b["attributes"]["kyu_number"] }
    # Expect exact ascending order
    expect(kyu_numbers).to eq(kyu_numbers.sort)
  end

  it "includes relationships for techniques and technique_types on belts" do
    orange_belt = belt_for("Orange")
    create(
      :belt_grade,
      user: user,
      belt: orange_belt,
      obtained_at: Date.current
    )

    # Attach a technique_type and a technique to one of the visible belts
    target_belt = syllabus.belts.find_by(kyu_number: 5) || orange_belt
    tt = create(:technique_type, belt: target_belt)
    create(:technique, technique_type: tt, belt: target_belt)

    json_api =
      serialize_json_api(
        described_class.new(syllabus, scope: { current_user: user }),
        includes: ["belts", "belts.technique_types", "belts.techniques"]
      )

    # Relationships are linkages; full belt resources are in `included`
    belts_linkage = json_api["data"]["relationships"]["belts"]["data"]
    included = json_api["included"] || []
    # Find the included belt resource for our target
    serialized_target = included.find { |r| r["type"] == "belts" && r["id"] == target_belt.id.to_s }
    expect(serialized_target).to be_present

    # Relationships should include techniques and technique_types keys on the included belt resource
    rels = serialized_target["relationships"]
    expect(rels).to include("techniques", "technique_types")
    expect(rels["techniques"]["data"]).to be_an(Array)
    expect(rels["technique_types"]["data"]).to be_an(Array)
  end

  it "serializes timestamps in ISO8601 and within a small tolerance of the model value" do
    orange_belt = belt_for("Orange")
    create(
      :belt_grade,
      user: user,
      belt: orange_belt,
      obtained_at: Date.current
    )

    json_api =
      serialize_json_api(
        described_class.new(syllabus, scope: { current_user: user }),
        includes: ["belts"]
      )

    included = json_api["included"] || []
    first_belt = included.find { |r| r["type"] == "belts" }
    serialized = first_belt["attributes"]
    model_belt = syllabus.belts.find(first_belt["id"].to_i)

    parsed = Time.parse(serialized["created_at"])
    expect((parsed - model_belt.created_at).abs).to be < 2
  end

  it "does not include belts with nil kyu_number in the returned belts" do
    # Add a belt and then null out its kyu_number (bypass validations) so the model will have a belt with nil kyu
    # Create the record directly and bypass validations to avoid uniqueness/validation failures
    b = Belt.new(syllabus: syllabus, colour: "TempForTest")
    b.save!(validate: false)
    b.update_columns(kyu_number: nil)

    orange_belt = belt_for("Orange")
    create(
      :belt_grade,
      user: user,
      belt: orange_belt,
      obtained_at: Date.current
    )

    json_api =
      serialize_json_api(
        described_class.new(syllabus, scope: { current_user: user }),
        includes: ["belts"]
      )

    included = json_api["included"] || []
    belt_included = included.select { |i| i["type"] == "belts" }
    kyu_numbers = belt_included.map { |b| b["attributes"]["kyu_number"] }
    expect(kyu_numbers).not_to include(nil)
  end
end
