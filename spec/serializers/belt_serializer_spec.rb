# frozen_string_literal: true

require "rails_helper"

RSpec.describe BeltSerializer, type: :serializer do
  let(:technique_type_1) do
    instance_double(
      "TechniqueType",
      id: 1,
      category: "Striking",
      sub_category: "Punches",
      created_at: Time.now,
      updated_at: Time.now
    ).tap do |d|
      allow(d).to receive(:class).and_return(TechniqueType)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
      allow(d).to receive(:syllabus).and_return(nil)
      allow(d).to receive(:belt).and_return(nil)
    end
  end
  let(:technique_type_2) do
    instance_double(
      "TechniqueType",
      id: 2,
      category: "Grappling",
      sub_category: "Takedowns",
      created_at: Time.now,
      updated_at: Time.now
    ).tap do |d|
      allow(d).to receive(:class).and_return(TechniqueType)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
      allow(d).to receive(:syllabus).and_return(nil)
      allow(d).to receive(:belt).and_return(nil)
    end
  end
  let(:technique_types) { [technique_type_1, technique_type_2] }

  let(:technique_1) do
    instance_double(
      "Technique",
      id: 1,
      summary: "Single Leg Takedown",
      created_at: Time.now,
      updated_at: Time.now,
      belt_id: 1
    ).tap do |d|
      allow(d).to receive(:class).and_return(Technique)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
    end
  end
  let(:technique_2) do
    instance_double(
      "Technique",
      id: 2,
      summary: "Rear Naked Choke",
      created_at: Time.now,
      updated_at: Time.now,
      belt_id: 1
    ).tap do |d|
      allow(d).to receive(:class).and_return(Technique)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
    end
  end
  let(:techniques) { [technique_1, technique_2] }

  let(:belt_grade_1) do
    instance_double(
      "BeltGrade",
      id: 1,
      belt_id: 1,
      user_id: 1,
      obtained_at: Date.today
    ).tap do |d|
      allow(d).to receive(:class).and_return(BeltGrade)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
    end
  end
  let(:belt_grade_2) do
    instance_double(
      "BeltGrade",
      id: 2,
      belt_id: 1,
      user_id: 1,
      obtained_at: Date.today
    ).tap do |d|
      allow(d).to receive(:class).and_return(BeltGrade)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
    end
  end
  let(:belt_grades) { [belt_grade_1, belt_grade_2] }

  let(:belt) do
    double(
      "Belt",
      id: 1,
      colour: "red",
      kyu_number: 7,
      syllabus_id: 1,
      created_at: Time.now,
      updated_at: Time.now,
      technique_types: technique_types,
      techniques: techniques,
      belt_grades: belt_grades
    ).tap do |d|
      allow(d).to receive(:class).and_return(Belt)
      allow(d).to receive(:read_attribute_for_serialization) { |attr|
        d.send(attr)
      }
    end
  end

  subject { serialize_json_api(described_class.new(belt)) }

  describe "serialized attributes" do
    it "includes the expected top-level keys and ID" do
      expect(subject["data"]["id"]).to eq("1")
      expect(subject["data"]["type"]).to eq("belts")
      expect(subject["data"]["attributes"].keys).to contain_exactly(
        "colour",
        "kyu_number",
        "effective_kyu_grade",
        "syllabus_id",
        "created_at",
        "updated_at"
      )
    end

    it "correctly serializes the attribute values" do
      attributes = subject["data"]["attributes"]
      expect(attributes["colour"]).to eq("red")
      expect(attributes["syllabus_id"]).to eq(1)
      expect(attributes["kyu_number"]).to eq(7)
      expect(attributes["effective_kyu_grade"]).to eq(7)
      expect(Time.parse(attributes["created_at"]).to_i).to eq(
        belt.created_at.to_i
      )
      expect(Time.parse(attributes["updated_at"]).to_i).to eq(
        belt.updated_at.to_i
      )
    end
  end

  describe "serialized relationships" do
    let(:relationships) { subject["data"]["relationships"] }

    it "includes the relationships key in the top-level data" do
      expect(relationships).to be_present
      expect(relationships.keys).to contain_exactly(
        "technique_types",
        "techniques",
        "belt_grades"
      )
    end

    it "correctly serializes the technique_types relationship" do
      expect(relationships["technique_types"]["data"].first["type"]).to eq(
        "technique_types"
      )
      expect(relationships["technique_types"]["data"].first["id"]).to eq("1")
      expect(relationships["technique_types"]["data"].size).to eq(
        technique_types.size
      )
    end

    it "correctly serializes the techniques relationship" do
      expect(relationships["techniques"]["data"].first["type"]).to eq(
        "techniques"
      )
      expect(relationships["techniques"]["data"].first["id"]).to eq("1")
      expect(relationships["techniques"]["data"].size).to eq(techniques.size)
    end

    it "correctly serializes the belt_grades relationship" do
      expect(relationships["belt_grades"]["data"].first["type"]).to eq(
        "belt_grades"
      )
      expect(relationships["belt_grades"]["data"].first["id"]).to eq("1")
      expect(relationships["belt_grades"]["data"].size).to eq(belt_grades.size)
    end
  end

  describe "effective_kyu_grade edge cases" do
    it "returns nil when kyu_number is nil" do
      belt_nil =
        double(
          "Belt",
          id: 2,
          colour: "Black",
          kyu_number: nil,
          syllabus_id: nil,
          created_at: Time.now,
          updated_at: Time.now,
          technique_types: [],
          techniques: [],
          belt_grades: []
        )
      allow(belt_nil).to receive(:class).and_return(Belt)
      allow(belt_nil).to receive(:read_attribute_for_serialization) { |attr|
        belt_nil.send(attr)
      }

      parsed = serialize_json_api(described_class.new(belt_nil))
      expect(parsed["data"]["attributes"]["effective_kyu_grade"]).to be_nil
    end

    it "wraps kyu_number 9 to 1" do
      belt9 =
        double(
          "Belt",
          id: 3,
          colour: "Custom",
          kyu_number: 9,
          syllabus_id: nil,
          created_at: Time.now,
          updated_at: Time.now,
          technique_types: [],
          techniques: [],
          belt_grades: []
        )
      allow(belt9).to receive(:class).and_return(Belt)
      allow(belt9).to receive(:read_attribute_for_serialization) { |attr|
        belt9.send(attr)
      }

      parsed = serialize_json_api(described_class.new(belt9))
      expect(parsed["data"]["attributes"]["effective_kyu_grade"]).to eq(1)
      expect(parsed["data"]["attributes"]["effective_kyu_grade"]).to be_a(
        Integer
      )
    end

    it "maps 16 to 8" do
      belt16 =
        double(
          "Belt",
          id: 4,
          colour: "Another",
          kyu_number: 16,
          syllabus_id: nil,
          created_at: Time.now,
          updated_at: Time.now,
          technique_types: [],
          techniques: [],
          belt_grades: []
        )
      allow(belt16).to receive(:class).and_return(Belt)
      allow(belt16).to receive(:read_attribute_for_serialization) { |attr|
        belt16.send(attr)
      }

      parsed = serialize_json_api(described_class.new(belt16))
      expect(parsed["data"]["attributes"]["effective_kyu_grade"]).to eq(8)
    end
  end

  describe "included resources and empty relationships" do
    it "includes techniques and technique_types when requested and exposes their attributes" do
      # Use build_stubbed objects from FactoryBot so serializers can traverse associations
      tt = build_stubbed(:technique_type)
      tech =
        build_stubbed(
          :technique,
          summary: "Single Leg Takedown",
          technique_type: tt
        )
      bg = build_stubbed(:belt_grade)
      belt_instance =
        build_stubbed(
          :belt,
          technique_types: [tt],
          techniques: [tech],
          belt_grades: [bg]
        )

      parsed =
        serialize_json_api(
          described_class.new(belt_instance),
          includes: %i[techniques technique_types belt_grades]
        )
      included = parsed["included"]

      types = included.map { |i| i["type"] }
      expect(types).to include("techniques")
      expect(types).to include("technique_types")
      expect(types).to include("belt_grades")

      tech_inc = included.find { |i| i["type"] == "techniques" }
      expect(tech_inc["attributes"]["summary"]).to eq("Single Leg Takedown")
    end

    it "handles empty relationships without error" do
      belt_empty =
        double(
          "Belt",
          id: 5,
          colour: "Empty",
          kyu_number: 8,
          syllabus_id: nil,
          created_at: Time.now,
          updated_at: Time.now,
          technique_types: [],
          techniques: [],
          belt_grades: []
        )
      allow(belt_empty).to receive(:class).and_return(Belt)
      allow(belt_empty).to receive(:read_attribute_for_serialization) { |attr|
        belt_empty.send(attr)
      }

      parsed = serialize_json_api(described_class.new(belt_empty))
      relationships = parsed["data"]["relationships"]
      expect(relationships["techniques"]["data"]).to eq([])
      expect(relationships["technique_types"]["data"]).to eq([])
      expect(relationships["belt_grades"]["data"]).to eq([])
    end
  end

  describe "collection serialization" do
    it "serializes an array of belts producing an array in data" do
      belt_a = belt
      belt_b =
        double(
          "Belt",
          id: 6,
          colour: "Blue",
          kyu_number: 5,
          syllabus_id: nil,
          created_at: Time.now,
          updated_at: Time.now,
          technique_types: [],
          techniques: [],
          belt_grades: []
        )
      allow(belt_b).to receive(:class).and_return(Belt)
      allow(belt_b).to receive(:read_attribute_for_serialization) { |attr|
        belt_b.send(attr)
      }

      parsed = serialize_json_api([belt_a, belt_b])
      expect(parsed["data"]).to be_an(Array)
      expect(parsed["data"].length).to eq(2)
    end
  end
end
