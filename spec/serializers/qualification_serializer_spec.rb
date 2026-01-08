require "rails_helper"

RSpec.describe QualificationSerializer do
  # We use `let!` to create the factory-generated records once per test run,
  # ensuring that they are available for all tests in this suite.
  let(:belt) { build_stubbed(:belt) }
  let(:qualification) do
    build_stubbed(:qualification, belt: belt, level: "Test Level")
  end

  # Define the objects used for serialization in a consistent way.
  let(:serializer) { described_class.new(qualification) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer) }
  let(:json_response) { JSON.parse(serialization.to_json) }

  # Test that the serializer includes the correct attributes.
  describe "attributes" do
    it "serializes the correct attributes" do
      # The `id` is a top-level key in JSON:API, so we only check the attributes hash.
      attributes = %w[level created_at updated_at belt_id]
      expect(json_response["data"]["attributes"].keys).to match_array(
        attributes
      )
    end

    it "serializes top-level id and type" do
      parsed = serialize_json_api(qualification)
      expect(parsed["data"]["id"]).to eq(qualification.id.to_s)
      expect(parsed["data"]["type"]).to eq("qualifications")
    end

    # NEW TEST: Ensure attribute values are correctly serialized.
    it "serializes the correct attribute values" do
      attributes = json_response["data"]["attributes"]
      expect(attributes["level"]).to eq(qualification.level)
      expect(attributes["belt_id"]).to eq(qualification.belt_id)
      # We check the serialized dates against their ISO8601 format to ensure consistency.
      expect(attributes["created_at"]).to eq(
        qualification.created_at.iso8601(3)
      )
      expect(attributes["updated_at"]).to eq(
        qualification.updated_at.iso8601(3)
      )
    end
  end

  # Test that the serializer correctly formats associations as relationships.
  describe "associations" do
    # This test ensures that the `belongs_to :belt` association is correctly
    # represented in the JSON:API relationships hash.
    it "serializes the belt association" do
      relationship_data = json_response["data"]["relationships"]["belt"]

      # Expect the relationship data to be present and contain the correct ID and type.
      expect(relationship_data).to be_present
      # IDs are always strings in the JSON output, so we must compare with a string.
      expect(relationship_data["data"]["id"]).to eq(belt.id.to_s)
      # The type is pluralized by default in JSON:API, so we update the test.
      expect(relationship_data["data"]["type"]).to eq("belts")
    end

    it "serializes nil belt relationship as null when belt is nil" do
      q_nil = build_stubbed(:qualification, belt: nil)
      parsed = serialize_json_api(q_nil)
      relationship_data = parsed["data"]["relationships"]["belt"]
      expect(relationship_data["data"]).to be_nil
    end
  end

  describe "includes and collections" do
    it "includes belt when requested via includes option" do
      parsed = serialize_json_api(qualification, includes: [:belt])
      included = parsed["included"] || []
      belt_inc = included.find { |i| i["type"] == "belts" }
      expect(belt_inc).to be_present
      expect(belt_inc["attributes"]["colour"]).to eq(belt.colour)
    end

    it "deduplicates included belt when serializing a collection" do
      q2 = build_stubbed(:qualification, belt: belt)
      parsed = serialize_json_api([qualification, q2], includes: [:belt])
      included = parsed["included"] || []
      belt_included = included.select { |i| i["type"] == "belts" }
      expect(parsed["data"]).to be_an(Array)
      expect(parsed["data"].length).to eq(2)
      expect(belt_included.length).to eq(1)
    end
  end

  describe "timestamp tolerance" do
    it "parses created_at and updated_at close to model times" do
      parsed = serialize_json_api(qualification)
      attrs = parsed["data"]["attributes"]
      expect(Time.parse(attrs["created_at"])).to be_within(1.second).of(
        qualification.created_at
      )
      expect(Time.parse(attrs["updated_at"])).to be_within(1.second).of(
        qualification.updated_at
      )
    end
  end
end
