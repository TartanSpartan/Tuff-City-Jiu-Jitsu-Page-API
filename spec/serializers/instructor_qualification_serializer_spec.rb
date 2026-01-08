# spec/serializers/instructor_qualification_serializer_spec.rb

require "rails_helper"
# The `InstructorQualificationSerializer` spec tests that the serializer correctly
# formats the JSON output for an `InstructorQualification` record.
RSpec.describe InstructorQualificationSerializer do
  # Use build_stubbed to avoid DB writes; serializer only needs to read attributes
  let(:user) { build_stubbed(:user) }
  let(:belt) { build_stubbed(:belt) }
  let(:qualification) { build_stubbed(:qualification) }
  let(:belt_grade) { build_stubbed(:belt_grade) }
  let(:instructor_qualification) do
    build_stubbed(
      :instructor_qualification,
      user: user,
      belt: belt,
      qualification: qualification,
      belt_grade: belt_grade
    )
  end

  # Use the test helper to produce a parsed JSON:API hash
  let(:json_response) { serialize_json_api(instructor_qualification) }

  # --- Attribute Serialization Tests ---
  describe "attributes" do
    # This test ensures that the serializer is including all the expected attributes.
    it "serializes the correct attributes" do
      # The `id` is no longer included in this list, as per the JSON:API specification.
      attributes = %w[
        achieved_at
        user_id
        belt_id
        belt_grade_id
        created_at
        updated_at
        qualification_id
      ]
      expect(json_response["data"]["attributes"].keys).to match_array(
        attributes
      )
    end

    it "serializes top-level id and type" do
      parsed = serialize_json_api(instructor_qualification)
      expect(parsed["data"]["id"]).to eq(instructor_qualification.id.to_s)
      expect(parsed["data"]["type"]).to eq("instructor_qualifications")
    end

    # NEW TEST: Ensure that the `achieved_at` attribute is serialized with the correct value.
    it "serializes the achieved_at attribute correctly" do
      instructor_qualification_achieved =
        build_stubbed(:instructor_qualification, :achieved)
      parsed = serialize_json_api(instructor_qualification_achieved)

      expect(parsed["data"]["attributes"]["achieved_at"]).to eq(
        instructor_qualification_achieved.achieved_at.iso8601(3)
      )
    end

    it "serializes created_at and updated_at as ISO8601 strings" do
      iq = build_stubbed(:instructor_qualification)
      parsed = serialize_json_api(iq)

      expect(parsed["data"]["attributes"]["created_at"]).to eq(
        iq.created_at.iso8601(3)
      )
      expect(parsed["data"]["attributes"]["updated_at"]).to eq(
        iq.updated_at.iso8601(3)
      )
    end

    it "omits achieved_at when it is nil" do
      iq_nil = build_stubbed(:instructor_qualification, achieved_at: nil)
      parsed = serialize_json_api(iq_nil)

      expect(parsed["data"]["attributes"]["achieved_at"]).to be_nil
    end
  end

  # --- Association Serialization Tests ---
  # These tests ensure that the associated records are correctly serialized
  # as relationships in the JSON:API output.
  describe "associations" do
    # Test the `belongs_to :qualification` association.
    it "serializes the qualification association" do
      relationship_data =
        json_response["data"]["relationships"]["qualification"]

      expect(relationship_data).to be_present
      expect(relationship_data["data"]).to be_present
      # ID comparison is now a string to match the JSON parsing.
      expect(relationship_data["data"]["id"]).to eq(qualification.id.to_s)
      # The expected type is now plural, as per the JSON:API standard.
      expect(relationship_data["data"]["type"]).to eq("qualifications")
    end

    # Test the `belongs_to :user` association.
    it "serializes the user association" do
      relationship_data = json_response["data"]["relationships"]["user"]
      expect(relationship_data).to be_present
      expect(relationship_data["data"]["id"]).to eq(user.id.to_s)
      # The expected type is now plural, as per the JSON:API standard.
      expect(relationship_data["data"]["type"]).to eq("users")
    end

    # NEW TEST: Test the optional `user` association when it is nil.
    it "serializes the user association as null when it is nil" do
      instructor_qualification_no_user =
        build_stubbed(:instructor_qualification, user: nil)
      parsed = serialize_json_api(instructor_qualification_no_user)

      relationship_data = parsed["data"]["relationships"]["user"]
      expect(relationship_data["data"]).to be_nil
    end

    # Test the `belongs_to :belt` association.
    it "serializes the belt association" do
      relationship_data = json_response["data"]["relationships"]["belt"]
      expect(relationship_data).to be_present
      expect(relationship_data["data"]["id"]).to eq(belt.id.to_s)
      # The expected type is now plural, as per the JSON:API standard.
      expect(relationship_data["data"]["type"]).to eq("belts")
    end

    # Test the `belongs_to :belt_grade` association.
    it "serializes the belt_grade association" do
      relationship_data = json_response["data"]["relationships"]["belt_grade"]
      expect(relationship_data).to be_present
      expect(relationship_data["data"]["id"]).to eq(belt_grade.id.to_s)
      # The expected type is now plural, as per the JSON:API standard.
      expect(relationship_data["data"]["type"]).to eq("belt_grades")
    end

    # NEW TEST: Test the optional `belt_grade` association when it is nil.
    it "serializes the belt_grade association as null when it is nil" do
      instructor_qualification_no_belt_grade =
        build_stubbed(:instructor_qualification, :no_belt_grade)
      parsed = serialize_json_api(instructor_qualification_no_belt_grade)

      relationship_data = parsed["data"]["relationships"]["belt_grade"]
      expect(relationship_data["data"]).to be_nil
    end
  end

  describe "included resources" do
    it "includes user, belt, qualification and belt_grade when requested" do
      parsed =
        serialize_json_api(
          instructor_qualification,
          includes: %i[user belt qualification belt_grade]
        )
      included = parsed["included"]

      types = included.map { |i| i["type"] }
      expect(types).to include(
        "users",
        "belts",
        "qualifications",
        "belt_grades"
      )

      user_inc = included.find { |i| i["type"] == "users" }
      expect(user_inc["attributes"]["email"]).to eq(user.email)

      belt_inc = included.find { |i| i["type"] == "belts" }
      expect(belt_inc["attributes"]["colour"]).to eq(belt.colour)

      qual_inc = included.find { |i| i["type"] == "qualifications" }
      expect(qual_inc["attributes"]["level"]).to eq(qualification.level)

      bg_inc = included.find { |i| i["type"] == "belt_grades" }
      # If a belt_grade was present on the subject, ensure included attrs match
      if belt_grade
        expect(bg_inc["attributes"]["grade_name"]).to eq(belt_grade.grade_name)
      end
    end

    it "does not include resources when includes is not requested" do
      parsed = serialize_json_api(instructor_qualification)
      expect(parsed["included"]).to be_nil
    end

    it "deduplicates included resources when serializing a collection" do
      # Two instructor qualifications that share the same user
      iq2 =
        build_stubbed(
          :instructor_qualification,
          user: user,
          belt: belt,
          qualification: qualification,
          belt_grade: belt_grade
        )
      parsed =
        serialize_json_api([instructor_qualification, iq2], includes: [:user])
      included = parsed["included"] || []

      # Only one user should be present in included
      user_included = included.select { |i| i["type"] == "users" }
      expect(user_included.length).to eq(1)
    end

    it "includes only requested resources when partial includes are used" do
      parsed =
        serialize_json_api(instructor_qualification, includes: [:qualification])
      included = parsed["included"] || []
      expect(included.map { |i| i["type"] }).to contain_exactly(
        "qualifications"
      )
    end

    it "serializes a collection of instructor qualifications" do
      iq2 =
        build_stubbed(
          :instructor_qualification,
          user: user,
          belt: belt,
          qualification: qualification,
          belt_grade: belt_grade
        )
      parsed =
        serialize_json_api([instructor_qualification, iq2], includes: [:user])
      expect(parsed["data"]).to be_an(Array)
      expect(parsed["data"].length).to eq(2)
    end
  end
end
