require "rails_helper"

RSpec.describe UserSerializer, type: :serializer do
  let(:object) do
    build_stubbed(
      :user,
      first_aid_achievement_date: nil,
      first_aid_expiry_date: nil
    )
  end

  describe "serialized attributes" do
    context "includes the expected top-level keys and ID" do
      let(:parsed_json) { serialize_json_api(UserSerializer.new(object)) }

      it "includes the top-level keys" do
        expect(parsed_json).to have_key("data")
        expect(parsed_json["data"]).to have_key("id")
        expect(parsed_json["data"]).to have_key("type")
        expect(parsed_json["data"]).to have_key("attributes")
        expect(parsed_json["data"]).to have_key("relationships")
      end

      it "includes the correct ID" do
        expect(parsed_json["data"]["id"]).to eq(object.id.to_s)
      end
    end

    context "when the user has first-aid dates" do
      let(:user) do
        build_stubbed(
          :user,
          first_name: "John",
          last_name: "Doe",
          email: "john.doe@example.com",
          is_admin: true,
          dues_paid: true,
          owns_gi: false,
          has_first_aid_qualification: true,
          first_aid_achievement_date: Date.today,
          first_aid_expiry_date: Date.today + 2.years,
          created_at: 1.day.ago,
          updated_at: 1.hour.ago
        )
      end

      let(:parsed_json) { serialize_json_api(UserSerializer.new(user)) }
      let(:attributes) { parsed_json["data"]["attributes"] }

      it "serializes the attribute values including ISO8601 dates" do
        expect(attributes["first_name"]).to eq(user.first_name)
        expect(attributes["last_name"]).to eq(user.last_name)
        expect(attributes["email"]).to eq(user.email)
        expect(attributes["is_admin"]).to eq(user.is_admin)
        expect(attributes["dues_paid"]).to eq(user.dues_paid)
        expect(attributes["owns_gi"]).to eq(user.owns_gi)
        expect(attributes["has_first_aid_qualification"]).to eq(
          user.has_first_aid_qualification
        )

        expect(
          Time.parse(attributes["first_aid_achievement_date"])
        ).to be_within(1.second).of(user.first_aid_achievement_date)

        expect(Time.parse(attributes["first_aid_expiry_date"])).to be_within(
          1.second
        ).of(user.first_aid_expiry_date)

        expect(Time.parse(attributes["created_at"])).to be_within(1.second).of(
          user.created_at
        )
        expect(Time.parse(attributes["updated_at"])).to be_within(1.second).of(
          user.updated_at
        )
      end
    end

    context "when the user lacks first-aid dates" do
      let(:user) do
        build_stubbed(
          :user,
          has_first_aid_qualification: false,
          first_aid_achievement_date: nil,
          first_aid_expiry_date: nil
        )
      end

      let(:parsed_json) { serialize_json_api(UserSerializer.new(user)) }
      let(:attributes) { parsed_json["data"]["attributes"] }

      it "omits first-aid date attributes (nil)" do
        expect(attributes["first_aid_achievement_date"]).to be_nil
        expect(attributes["first_aid_expiry_date"]).to be_nil
      end
    end
  end

  describe "associations" do
    let(:parsed_json) { serialize_json_api(UserSerializer.new(object)) }
    let(:relationships) { parsed_json["data"]["relationships"] }

    let!(:bg) { build_stubbed(:belt_grade, user: object) }
    let!(:iq) { build_stubbed(:instructor_qualification, user: object) }
    let!(:syllabus) { build_stubbed(:syllabus) }

    before do
      # Use build_stubbed and stub association readers so serializers can traverse them
      allow(object).to receive(:belt_grades).and_return([bg])
      allow(object).to receive(:instructor_qualifications).and_return([iq])
      allow(object).to receive(:syllabi).and_return([syllabus])
    end

    it "includes the relationships with a data key pointing to the correct ID and type" do
      expect(relationships["belt_grades"]).to have_key("data")
      expect(relationships["instructor_qualifications"]).to have_key("data")
      expect(relationships["syllabi"]).to have_key("data")

      expect(relationships["belt_grades"]["data"].first["id"]).to eq(bg.id.to_s)
      expect(relationships["belt_grades"]["data"].first["type"]).to eq(
        "belt_grades"
      )

      expect(
        relationships["instructor_qualifications"]["data"].first["id"]
      ).to eq(iq.id.to_s)
      expect(
        relationships["instructor_qualifications"]["data"].first["type"]
      ).to eq("instructor_qualifications")

      expect(relationships["syllabi"]["data"].first["id"]).to eq(
        syllabus.id.to_s
      )
      expect(relationships["syllabi"]["data"].first["type"]).to eq("syllabi")
    end

    it "includes actual resource content for included belt_grades" do
      # Use DB-backed records so included contains full serialized attributes
      u = create(:user)
      bg = create(:belt_grade, user: u)

      included_json =
        JSON.parse(
          ActiveModelSerializers::SerializableResource.new(
            u,
            include: ["belt_grades"]
          ).to_json
        )

      included = included_json["included"]
      expect(included).to be_present
      bg_objs = included.select { |r| r["type"] == "belt_grades" }
      expect(bg_objs).not_to be_empty
      included_bg = bg_objs.find { |r| r["id"] == bg.id.to_s }
      expect(included_bg).to be_present
      # Verify a representative attribute matches the DB record
      expect(Time.parse(included_bg["attributes"]["obtained_at"])).to be_within(
        2.seconds
      ).of(bg.obtained_at.to_time)
    end

    it "includes actual resource content for included instructor_qualifications" do
      u = create(:user)
      iq = create(:instructor_qualification, user: u)

      included_json =
        JSON.parse(
          ActiveModelSerializers::SerializableResource.new(
            u,
            include: ["instructor_qualifications"]
          ).to_json
        )

      included = included_json["included"]
      expect(included).to be_present
      iq_objs = included.select { |r| r["type"] == "instructor_qualifications" }
      expect(iq_objs).not_to be_empty
      included_iq = iq_objs.find { |r| r["id"] == iq.id.to_s }
      expect(included_iq).to be_present
      # Check an attribute that should be present on the serializer
      expect(Time.parse(included_iq["attributes"]["achieved_at"])).to be_within(
        2.seconds
      ).of(iq.achieved_at.to_time)
    end

    it "includes actual resource content for included syllabi" do
      u = create(:user)
      # Create a syllabus and associate via user_syllabi
      s = create(:syllabus)
      create(:user_syllabus, user: u, syllabus: s)

      included_json =
        JSON.parse(
          ActiveModelSerializers::SerializableResource.new(
            u,
            include: ["syllabi"]
          ).to_json
        )

      included = included_json["included"]
      expect(included).to be_present
      s_objs =
        included.select do |r|
          r["type"] == "syllabi" || r["type"] == "syllabus"
        end
      expect(s_objs).not_to be_empty
      included_s = s_objs.find { |r| r["id"] == s.id.to_s }
      expect(included_s).to be_present
      # Verify a representative attribute exists
      expect(included_s["attributes"]["country"]).to eq(s.country)
    end

    context "includes the belt_grades relationship with correct links" do
      it "includes the belt_grades relationship and links" do
        relationships = parsed_json["data"]["relationships"]["belt_grades"]
        expect(relationships).to have_key("links")
        expect(relationships["links"]).to have_key("related")
        expect(relationships["links"]["related"]).to eq(
          "/users/#{object.id}/belt_grades"
        )
      end
    end

    context "includes the instructor_qualifications relationship with correct link" do
      it "includes the instructor_qualifications relationship and link" do
        relationships =
          parsed_json["data"]["relationships"]["instructor_qualifications"]
        expect(relationships).to have_key("links")
        expect(relationships["links"]).to have_key("related")
        expect(relationships["links"]["related"]).to eq(
          "/users/#{object.id}/instructor_qualifications"
        )
      end
    end

    context "includes the syllabi relationship with correct links" do
      it "includes the syllabi relationship and links" do
        relationships = parsed_json["data"]["relationships"]["syllabi"]
        expect(relationships).to have_key("links")
        expect(relationships["links"]).to have_key("related")
        expect(relationships["links"]["related"]).to eq(
          "/users/#{object.id}/syllabi"
        )
      end
    end
  end
end
