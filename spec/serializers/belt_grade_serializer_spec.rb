# frozen_string_literal: true

require "rails_helper"
# These are necessary for direct testing of ActiveModel Serializers.
require "active_model_serializers/serialization_context"
require "active_model_serializers/adapter"

RSpec.describe BeltGradeSerializer do
  # This is a good way to verify that the serializer class is being properly loaded.
  it "is a valid serializer class" do
    expect(described_class).to be < ActiveModel::Serializer
  end

  # We use FactoryBot to create a real BeltGrade object with its required associations.
  let(:user) { build_stubbed(:user) }
  let(:belt) { build_stubbed(:belt) }
  let(:belt_grade) { build_stubbed(:belt_grade, user: user, belt: belt) }

  # The serializer instance, which is the subject of our tests.
  let(:serializer) { described_class.new(belt_grade) }

  # Parsed JSON API output for the main subject under test.
  let(:parsed_json) { serialize_json_api(serializer) }

  describe "attributes" do
    it "includes all expected attributes" do
      attributes = parsed_json["data"]["attributes"]

      # Test for the presence and values of each attribute.
      # Note that foreign keys are included in this serializer, which is tested here.
      expect(attributes["user_id"]).to eq(belt_grade.user_id)
      expect(attributes["belt_id"]).to eq(belt_grade.belt_id)
      expect(attributes["time_held"]).to eq(belt_grade.time_held)
      # Explicitly assert computed and derived attributes are present
      expect(attributes["grade_name"]).to eq(belt_grade.grade_name)
      expect(attributes["effective_kyu_grade"]).to eq(
        belt_grade.effective_kyu_grade
      )
      expect(attributes["obtained_at"]).to eq(belt_grade.obtained_at.iso8601)
      expect(attributes["created_at"]).to eq(belt_grade.created_at.iso8601(3))
      expect(attributes["updated_at"]).to eq(belt_grade.updated_at.iso8601(3))
    end
  end

  describe "computed/edge cases" do
    it "serializes Unknown grade_name when belt is nil" do
      bg = build_stubbed(:belt_grade, user: user, belt: nil)
      parsed = serialize_json_api(bg)
      attrs = parsed["data"]["attributes"]

      expect(attrs["grade_name"]).to eq("Unknown")
      # belt relationship should be null in the relationships object
      expect(parsed["data"]["relationships"]["belt"]["data"]).to be_nil
    end

    it "formats time_held for multi-year durations" do
      # Create a persisted record so timestamps are available
      long_held =
        build_stubbed(
          :belt_grade,
          user: user,
          belt: belt,
          obtained_at: 400.days.ago.to_date
        )
      parsed = serialize_json_api(long_held)
      attrs = parsed["data"]["attributes"]

      # Stub Date.current to a fixed date so the time_held output is deterministic
      allow(Date).to receive(:current).and_return(Date.new(2021, 3, 5))

      # Obtained on 2019-01-01 => difference to 2021-03-05 is 2 years and 2 months (795 days)
      long_held =
        build_stubbed(
          :belt_grade,
          user: user,
          belt: belt,
          obtained_at: Date.new(2019, 1, 1)
        )
      serializer = described_class.new(long_held)
      json =
        ActiveModelSerializers::Adapter::JsonApi.new(
          serializer,
          serialization_context:
            ActiveModelSerializers::SerializationContext.new
        ).to_json

      parsed = JSON.parse(json)
      attrs = parsed["data"]["attributes"]

      expect(attrs["time_held"]).to eq("2 years and 2 months")
    end
  end

  describe "included resources" do
    it "includes belt and user resources when requested" do
      # Use the main belt_grade subject (build_stubbed) and request includes
      parsed = serialize_json_api(belt_grade, includes: %i[belt user])

      included = parsed["included"]
      expect(included).to be_an(Array)

      types = included.map { |i| i["type"] }
      expect(types).to include("belts")
      expect(types).to include("users")

      user_inc = included.find { |i| i["type"] == "users" }
      belt_inc = included.find { |i| i["type"] == "belts" }

      expect(user_inc).not_to be_nil
      expect(user_inc["id"]).to eq(user.id.to_s)
      # Assert specific attributes on the included user resource
      expect(user_inc["attributes"]["email"]).to eq(user.email)

      expect(belt_inc).not_to be_nil
      expect(belt_inc["id"]).to eq(belt.id.to_s)
      # Assert specific attributes on the included belt resource
      expect(belt_inc["attributes"]["colour"]).to eq(belt.colour)
    end
  end

  describe "relationships" do
    it "includes the belongs_to user relationship" do
      relationships = parsed_json["data"]["relationships"]

      # Test for the presence of the 'user' relationship and its data.
      expect(relationships).to have_key("user")
      expect(relationships["user"]["data"]["id"]).to eq(user.id.to_s)
      # In JSON API, types are pluralized.
      expect(relationships["user"]["data"]["type"]).to eq("users")
    end

    context "when the user association is optional (nil)" do
      let(:belt_grade) { build_stubbed(:belt_grade, user: nil, belt: belt) }

      it "returns a null relationship for user" do
        relationships = parsed_json["data"]["relationships"]
        expect(relationships["user"]["data"]).to be_nil
      end
    end

    it "includes the has_one belt relationship" do
      relationships = parsed_json["data"]["relationships"]

      # Test for the presence of the 'belt' relationship and its data.
      expect(relationships).to have_key("belt")
      expect(relationships["belt"]["data"]["id"]).to eq(belt.id.to_s)
      # In JSON API, types are pluralized.
      expect(relationships["belt"]["data"]["type"]).to eq("belts")
    end
  end
end
