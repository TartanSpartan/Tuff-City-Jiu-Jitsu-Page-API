# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyllabusSerializer, type: :serializer do
  # Create a syllabus with associated belts and technique types for a comprehensive test.
  # We explicitly set the country to 'NZ' so the test can assert the expected value.
  let(:syllabus) { create(:syllabus, :with_belts, year: 2024, country: "NZ") }

  # The subject of our test is the serialized output of the syllabus.
  # We use ActiveModelSerializers::SerializableResource to ensure the adapter is applied correctly,
  # which is how the serializer would be used in a controller.
  subject(:serialization) do
    ActiveModelSerializers::SerializableResource.new(syllabus).serializable_hash
  end

  # Define helper variables to access different parts of the serialized hash.
  let(:data) { serialization[:data] }
  let(:attributes) { data[:attributes] }
  let(:relationships) { data[:relationships] }

  # ---
  # Test the top-level structure of the serialization.
  # ---
  describe "top-level" do
    it "includes the expected top-level keys and ID" do
      expect(data.keys).to contain_exactly(
        :id,
        :type,
        :attributes,
        :relationships
      )
      expect(data[:id]).to eq(syllabus.id.to_s)
      # The `type` is a pluralized string in JSON:API, not a symbol.
      expect(data[:type]).to eq("syllabi")
    end
  end

  # ---
  # Test the serialized attributes.
  # ---
  describe "serialized attributes" do
    it "includes the expected attributes" do
      # The `id` is correctly moved to the top level, so it is not an attribute.
      expect(attributes.keys).to contain_exactly(
        :country,
        :year,
        :is_primary_admin_syllabus,
        :is_secondary_admin_syllabus,
        :created_at,
        :updated_at
      )
    end

    it "correctly serializes the attribute values" do
      expect(attributes[:country]).to eq("NZ")
      expect(attributes[:year]).to eq(2024)
      # We check that the values are present and match. Using `be_within(1.second)` is a good practice for time attributes.
      expect(attributes[:created_at]).to be_within(1.second).of(
        syllabus.created_at
      )
      expect(attributes[:updated_at]).to be_within(1.second).of(
        syllabus.updated_at
      )
    end
  end

  # ---
  # Test the serialized relationships.
  # ---
  describe "serialized relationships" do
    it "includes the relationships key" do
      expect(data).to have_key(:relationships)
    end

    it "includes the correct relationship keys" do
      expect(relationships.keys).to contain_exactly(:belts, :technique_types)
    end

    describe "belts relationship" do
      let(:belts_data) { relationships[:belts][:data] }

      it "correctly serializes the belts relationship" do
        # The factory creates 8 standard kyu belts.
        expect(belts_data.size).to eq(8)
        # Check the structure of the first belt relationship object.
        expect(belts_data.first.keys).to contain_exactly(:id, :type)
        # The `type` is a pluralized string in JSON:API, not a symbol.
        expect(belts_data.first[:type]).to eq("belts")
      end
    end

    describe "technique_types relationship" do
      let(:technique_types_data) { relationships[:technique_types][:data] }

      it "correctly serializes the technique_types relationship" do
        # The factory creates 9 technique types.
        expect(technique_types_data.size).to eq(9)
        # Check the structure of the first technique_type relationship object.
        expect(technique_types_data.first.keys).to contain_exactly(:id, :type)
        # The `type` is a pluralized string in JSON:API, not a symbol.
        expect(technique_types_data.first[:type]).to eq("technique_types")
      end
    end
  end

  describe "scoped and include behaviour" do
    let(:admin_user) { create(:user) }

    it "still exposes admin flags when serialized with a current_user scope (private endpoints)" do
      # Mark syllabus as primary/secondary admin for the assertion
      syllabus.update_columns(
        is_primary_admin_syllabus: true,
        is_secondary_admin_syllabus: false
      )

      scoped =
        ActiveModelSerializers::SerializableResource.new(
          syllabus,
          scope: {
            current_user: admin_user
          }
        ).serializable_hash

      scoped_attrs = scoped[:data][:attributes]
      expect(scoped_attrs[:is_primary_admin_syllabus]).to eq(true)
      expect(scoped_attrs[:is_secondary_admin_syllabus]).to eq(false)
    end

    it "does not eagerly include related resources unless requested via `include`" do
      # Default serialization should provide relationship linkages but not full included resources
      default_serialization =
        ActiveModelSerializers::SerializableResource.new(
          syllabus
        ).serializable_hash
      expect(default_serialization).not_to have_key(:included)

      # Request explicit inclusion of belts and technique_types
      included_serialization =
        ActiveModelSerializers::SerializableResource.new(
          syllabus,
          include: %w[belts technique_types]
        ).serializable_hash

      # The `included` key should now be present and contain belt and technique_type resources
      expect(included_serialization).to have_key(:included)
      included_types =
        included_serialization[:included].map { |r| r[:type] }.uniq
      expect(included_types).to include("belts", "technique_types")
    end
  end
end
