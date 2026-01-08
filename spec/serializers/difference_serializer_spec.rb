# frozen_string_literal: true

require "rails_helper"

RSpec.describe DifferenceSerializer, type: :serializer do
  # Use FactoryBot to create a simple instance of the associated models
  let(:technique) { build_stubbed(:technique, summary: "Technique A") }
  let(:compared_to_technique) do
    build_stubbed(:technique, summary: "Technique B")
  end

  # Create an instance of the Difference model to be serialized
  let(:difference) do
    build_stubbed(
      :difference,
      content: "This is a key difference.",
      technique: technique,
      compared_to_technique: compared_to_technique
    )
  end

  # Create an instance of the serializer with the Difference object.
  # We use the :include option to force the serialization of related records
  # into the `included` array, as expected by the test.
  subject(:serialization) do
    ActiveModelSerializers::SerializableResource.new(
      difference,
      include: %w[technique compared_to_technique]
    ).serializable_hash
  end

  # Define helper variables to access different parts of the serialized hash.
  let(:data) { serialization[:data] }
  let(:attributes) { data[:attributes] }
  let(:relationships) { data[:relationships] }
  let(:included) { serialization[:included] }

  # Test for the correct top-level JSON:API structure
  it "includes the required attributes" do
    # Check that the main object is under a 'data' key
    expect(data.keys).to include(:id, :type, :attributes, :relationships)
    # Check that the data object has the correct ID and type
    expect(data[:id]).to eq(difference.id.to_s)
    expect(data[:type]).to eq("differences")
    # Check that attributes are present under the 'attributes' key
    expect(attributes.keys).to include(:content, :created_at, :updated_at)
    # Check that relationships are present under the 'relationships' key
    expect(relationships.keys).to include(:technique, :compared_to_technique)
  end

  # Test that the content attribute is serialized correctly
  it "serializes the content attribute" do
    expect(attributes[:content]).to eq("This is a key difference.")
  end

  # Test that the has-one relationship to technique is serialized correctly
  it "serializes the associated technique" do
    # The technique relationship should have a data hash with an ID and type
    expect(relationships[:technique][:data][:id]).to eq(technique.id.to_s)
    expect(relationships[:technique][:data][:type]).to eq("techniques")
  end

  # Test that the has-one relationship to compared_to_technique is serialized correctly
  it "serializes the associated compared_to_technique" do
    # The compared_to_technique relationship should have a data hash with an ID and type
    expect(relationships[:compared_to_technique][:data][:id]).to eq(
      compared_to_technique.id.to_s
    )
    expect(relationships[:compared_to_technique][:data][:type]).to eq(
      "techniques"
    )
  end

  # Test for the inclusion of related records and their attributes
  it "includes the full technique objects in the included data" do
    # Check that the included array exists and has the correct number of items
    expect(included).to be_present
    expect(included.count).to eq(2)

    # Find the serialized technique and check its attributes
    serialized_technique =
      included.find { |item| item[:id] == technique.id.to_s }
    expect(serialized_technique).to be_present
    expect(serialized_technique[:attributes][:summary]).to eq("Technique A")

    # Find the serialized compared_to_technique and check its attributes
    serialized_compared_to_technique =
      included.find { |item| item[:id] == compared_to_technique.id.to_s }
    expect(serialized_compared_to_technique).to be_present
    expect(serialized_compared_to_technique[:attributes][:summary]).to eq(
      "Technique B"
    )
  end

  context "edge cases" do
    it "handles nil technique association" do
      diff =
        build_stubbed(
          :difference,
          technique: nil,
          compared_to_technique: compared_to_technique
        )
      hash =
        ActiveModelSerializers::SerializableResource.new(diff).serializable_hash
      rel = hash[:data][:relationships]
      expect(rel[:technique][:data]).to be_nil
      expect(rel[:compared_to_technique][:data][:id]).to eq(
        compared_to_technique.id.to_s
      )
    end

    it "handles nil compared_to_technique association" do
      diff =
        build_stubbed(
          :difference,
          technique: technique,
          compared_to_technique: nil
        )
      hash =
        ActiveModelSerializers::SerializableResource.new(diff).serializable_hash
      rel = hash[:data][:relationships]
      expect(rel[:compared_to_technique][:data]).to be_nil
      expect(rel[:technique][:data][:id]).to eq(technique.id.to_s)
    end

    it "respects partial includes (only technique)" do
      diff =
        build_stubbed(
          :difference,
          technique: technique,
          compared_to_technique: compared_to_technique
        )
      hash =
        ActiveModelSerializers::SerializableResource.new(
          diff,
          include: ["technique"]
        ).serializable_hash
      expect(hash[:included].count).to eq(1)
      expect(hash[:included].first[:type]).to eq("techniques")
      expect(hash[:included].first[:id]).to eq(technique.id.to_s)
    end

    it "returns no included data when not requested" do
      diff =
        build_stubbed(
          :difference,
          technique: technique,
          compared_to_technique: compared_to_technique
        )
      hash =
        ActiveModelSerializers::SerializableResource.new(diff).serializable_hash
      expect(hash[:included]).to be_nil.or be_empty
    end

    it "serializes timestamps in a parseable format" do
      diff =
        build_stubbed(
          :difference,
          technique: technique,
          compared_to_technique: compared_to_technique
        )
      hash =
        ActiveModelSerializers::SerializableResource.new(diff).serializable_hash
      created = hash[:data][:attributes][:created_at]
      # Adapter may return a String or a Time object depending on config.
      parsed = (created.is_a?(String) ? Time.parse(created) : created.to_time)
      # ensure the parsed time is close to the object's created_at
      expect(parsed).to be_within(2).of(diff.created_at)
    end

    it "serializes collections of differences" do
      d1 = build_stubbed(:difference, technique: technique)
      d2 = build_stubbed(:difference, technique: technique)
      hash =
        ActiveModelSerializers::SerializableResource.new(
          [d1, d2],
          include: ["technique"]
        ).serializable_hash
      expect(hash[:data]).to be_an(Array)
      expect(hash[:data].length).to eq(2)
    end
  end
end
