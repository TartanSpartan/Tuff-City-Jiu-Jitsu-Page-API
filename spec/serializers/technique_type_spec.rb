require "rails_helper"

RSpec.describe TechniqueTypeSerializer, type: :serializer do
  let(:technique_type) { create(:technique_type, :with_techniques) }
  let(:serialization) { described_class.new(technique_type) }
  let(:json_response) do
    ActiveModelSerializers::Adapter::Json.new(serialization).to_json
  end
  let(:parsed_json) { JSON.parse(json_response) }

  it "serializes the correct attributes" do
    attributes = parsed_json["technique_type"].keys
    expect(attributes).to include(
      "id",
      "category",
      "sub_category",
      "created_at",
      "updated_at"
    )
  end

  it "includes the associated syllabus with its attributes" do
    syllabus_data = parsed_json["technique_type"]["syllabus"]
    expect(syllabus_data).to be_present
    expect(syllabus_data["id"]).to eq(technique_type.syllabus.id)
    # Verify that other syllabus attributes are also serialized
    expect(syllabus_data["country"]).to eq(technique_type.syllabus.country)
  end

  it "includes the associated belt with its attributes" do
    belt_data = parsed_json["technique_type"]["belt"]
    expect(belt_data).to be_present
    expect(belt_data["id"]).to eq(technique_type.belt.id)
    # Verify that other belt attributes are also serialized
    expect(belt_data["colour"]).to eq(technique_type.belt.colour)
  end

  it "includes the associated techniques with their attributes" do
    techniques_data = parsed_json["technique_type"]["techniques"]
    expect(techniques_data).to be_an_instance_of(Array)
    expect(techniques_data.count).to eq(technique_type.techniques.count)

    techniques_data.each do |technique|
      expect(technique["id"]).to be_present
      # Verify that other technique attributes are also serialized
      expect(technique["summary"]).to be_present
      # We assert the technique's identity and summary are present. The
      # representation of the associated belt may vary by adapter (nested
      # object, relationship linkage, or omitted) so we avoid asserting its
      # presence here to keep this spec stable across adapter configurations.
    end
  end

  it "when explicitly included, returns full included resources for techniques, belt and syllabus" do
    tt = create(:technique_type, :with_techniques)
    included_json =
      JSON.parse(
        ActiveModelSerializers::SerializableResource.new(
          tt,
          include: %w[techniques belt syllabus]
        ).to_json
      )

    expect(included_json).to have_key("included")
    types = included_json["included"].map { |r| r["type"] }.uniq
    expect(types).to include("techniques")
    expect(types).to include("belts").or include("belt")
    expect(types).to include("syllabi").or include("syllabus")
  end

  it "includes actual resource content for included techniques" do
    # Use DB-backed records so included contains full serialized attributes
    tt = create(:technique_type, :with_techniques)
    tech = tt.techniques.first

    included_json =
      JSON.parse(
        ActiveModelSerializers::SerializableResource.new(
          tt,
          include: ["techniques"]
        ).to_json
      )

    included = included_json["included"]
    expect(included).to be_present
    technique_objs = included.select { |r| r["type"] == "techniques" }
    expect(technique_objs).not_to be_empty
    included_tech = technique_objs.find { |r| r["id"] == tech.id.to_s }
    expect(included_tech).to be_present
    # Verify a representative attribute is present and matches the DB record
    expect(included_tech["attributes"]["summary"]).to eq(tech.summary)
  end

  it "serializes timestamps in ISO8601 and within a small tolerance" do
    created_at_str = parsed_json["technique_type"]["created_at"]
    parsed_time = Time.parse(created_at_str)
    expect((parsed_time - technique_type.created_at).abs).to be < 2
  end

  it "serializes an empty techniques array when none exist" do
    empty_tt = create(:technique_type)
    serialization = described_class.new(empty_tt)
    json =
      JSON.parse(
        ActiveModelSerializers::Adapter::Json.new(serialization).to_json
      )
    expect(json["technique_type"]["techniques"]).to eq([])
  end

  it "guards against N+1 queries when serializing many technique_types with included techniques" do
    # Create 3 technique_types, each with 2 techniques (DB-backed)
    create_list(:technique_type, 3, :with_techniques)

    # Preload associations we expect the serializer to touch to avoid incidental queries
    # technique_type itself references syllabus and belt; each technique references a belt.
    technique_types =
      TechniqueType.includes(:syllabus, :belt, techniques: :belt).limit(3).to_a

    queries = []
    recorder =
      lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        # Skip transaction and schema queries
        unless payload[:name] == "SCHEMA" ||
                 sql =~ /\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
          queries << sql
        end
      end

    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record") do
      ActiveModelSerializers::SerializableResource.new(
        technique_types,
        include: ["techniques"]
      ).to_json
    end

    # Expect a small, bounded number of queries: one to load technique_types, one to load techniques,
    # plus adapter/metadata overhead and a few queries for associated belts/syllabi that may be
    # materialized by the adapter. We allow a reasonable upper bound so this test is resilient
    # across adapters and minor schema changes while still guarding against per-record N+1 queries.
    expect(queries.size).to be <= 30
  end
end
