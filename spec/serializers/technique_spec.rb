# spec/serializers/technique_serializer_spec.rb
require "rails_helper"

RSpec.describe TechniqueSerializer do
  # Use FactoryBot to create all associated data for the test subject.
  let(:technique_type) { build_stubbed(:technique_type) }
  let(:belt) { build_stubbed(:belt) }
  let(:technique) do
    build_stubbed(:technique, technique_type: technique_type, belt: belt)
  end

  # Build associated data using build_stubbed_list to avoid DB writes.
  let(:videos) { build_stubbed_list(:video, 2, technique: technique) }
  let(:differences) { build_stubbed_list(:difference, 3, technique: technique) }
  let(:comparisons) do
    build_stubbed_list(:difference, 1, compared_to_technique: technique)
  end

  before do
    # When using build_stubbed, ActiveRecord association readers won't automatically
    # return the built lists, so stub the association readers the serializer will call.
    allow(technique).to receive(:videos).and_return(videos)
    allow(technique).to receive(:differences).and_return(differences)
    allow(technique).to receive(:comparisons).and_return(comparisons)
  end

  let(:serializer) { described_class.new(technique) }
  let(:serialization) { ActiveModelSerializers::Adapter.create(serializer) }
  let(:json_response) { JSON.parse(serialization.to_json) }

  # The `data` key is added by the ActiveModelSerializers adapter.
  let(:serialized_attributes) { json_response["data"]["attributes"] }
  let(:serialized_relationships) { json_response["data"]["relationships"] }

  # New test to ensure the top-level id and type are serialized correctly.
  it "serializes the correct top-level id and type" do
    expect(json_response["data"]["id"]).to eq(technique.id.to_s)
    expect(json_response["data"]["type"]).to eq("techniques")
  end

  it "serializes the correct attributes" do
    attributes = %w[summary default_attack created_at updated_at]
    expect(serialized_attributes.keys).to match_array(attributes)
  end

  # New test to ensure the values of the attributes are correct.
  it "serializes the correct attribute values" do
    expect(serialized_attributes["summary"]).to eq(technique.summary)
  end

  it "serializes the technique_type association" do
    relationship_data = serialized_relationships["technique_type"]
    expect(relationship_data).to be_present
    expect(relationship_data["data"]["id"]).to eq(technique_type.id.to_s)
    expect(relationship_data["data"]["type"]).to eq("technique_types")
  end

  it "serializes the belt association" do
    relationship_data = serialized_relationships["belt"]
    expect(relationship_data).to be_present
    expect(relationship_data["data"]["id"]).to eq(belt.id.to_s)
    expect(relationship_data["data"]["type"]).to eq("belts")
  end

  it "serializes the videos association" do
    relationship_data = serialized_relationships["videos"]
    expect(relationship_data).to be_present
    expect(relationship_data["data"].count).to eq(videos.count)
    expect(relationship_data["data"].map { |item| item["id"] }).to match_array(
      videos.map(&:id).map(&:to_s)
    )
  end

  it "serializes the differences association" do
    relationship_data = serialized_relationships["differences"]
    expect(relationship_data).to be_present
    expect(relationship_data["data"].count).to eq(differences.count)
    expect(relationship_data["data"].map { |item| item["id"] }).to match_array(
      differences.map(&:id).map(&:to_s)
    )
  end

  it "serializes the comparisons association" do
    relationship_data = serialized_relationships["comparisons"]
    expect(relationship_data).to be_present
    expect(relationship_data["data"].count).to eq(comparisons.count)
    expect(relationship_data["data"].map { |item| item["id"] }).to match_array(
      comparisons.map(&:id).map(&:to_s)
    )
  end

  it "includes related resources when requested via include" do
    included_json =
      JSON.parse(
        ActiveModelSerializers::SerializableResource.new(
          technique,
          include: %w[videos differences comparisons]
        ).to_json
      )

    expect(included_json).to have_key("included")
    included_types = included_json["included"].map { |r| r["type"] }.uniq
    # videos and differences should appear in the included resources
    expect(included_types).to include("videos")
    expect(included_types).to include("differences")
  end

  it "serializes timestamps in ISO8601 and within a small tolerance" do
    parsed = Time.parse(serialized_attributes["created_at"])
    expect((parsed - technique.created_at).abs).to be < 2
  end

  it "does not expose *_id attributes in attributes (clients should use relationships)" do
    expect(serialized_attributes).not_to have_key("technique_type_id")
    expect(serialized_attributes).not_to have_key("belt_id")
  end

  it "outputs empty arrays for missing associations rather than nil" do
    no_assoc = build_stubbed(:technique)
    allow(no_assoc).to receive(:videos).and_return([])
    allow(no_assoc).to receive(:differences).and_return([])
    allow(no_assoc).to receive(:comparisons).and_return([])

    json =
      JSON.parse(
        ActiveModelSerializers::Adapter.create(
          described_class.new(no_assoc)
        ).to_json
      )
    rels = json["data"]["relationships"]
    expect(rels["videos"]["data"]).to eq([])
    expect(rels["differences"]["data"]).to eq([])
    expect(rels["comparisons"]["data"]).to eq([])
  end

  it "includes actual resource content for included videos" do
    # Use DB-backed records so included contains full serialized attributes
    t = create(:technique, :with_videos, videos_count: 1)
    v = t.videos.first

    included_json =
      JSON.parse(
        ActiveModelSerializers::SerializableResource.new(
          t,
          include: ["videos"]
        ).to_json
      )

    included = included_json["included"]
    expect(included).to be_present
    video_objs = included.select { |r| r["type"] == "videos" }
    expect(video_objs).not_to be_empty
    # Find the included video that matches our created video's id
    included_video = video_objs.find { |r| r["id"] == v.id.to_s }
    expect(included_video).to be_present
    expect(included_video["attributes"]["url"]).to eq(v.url)
  end

  it "includes actual resource content for included differences and comparisons" do
    # DB-backed: create a technique with one outgoing difference and one incoming comparison
    t = create(:technique)
    diff =
      create(
        :difference,
        technique: t,
        compared_to_technique: create(:technique)
      )
    comp =
      create(
        :difference,
        technique: create(:technique),
        compared_to_technique: t
      )

    included_json =
      JSON.parse(
        ActiveModelSerializers::SerializableResource.new(
          t,
          include: %w[differences comparisons]
        ).to_json
      )

    included = included_json["included"]
    expect(included).to be_present
    diff_objs = included.select { |r| r["type"] == "differences" }
    expect(diff_objs).not_to be_empty

    included_diff = diff_objs.find { |r| r["id"] == diff.id.to_s }
    included_comp = diff_objs.find { |r| r["id"] == comp.id.to_s }

    expect(included_diff).to be_present
    expect(included_comp).to be_present
    expect(included_diff["attributes"]["content"]).to eq(diff.content)
    expect(included_comp["attributes"]["content"]).to eq(comp.content)
  end

  it "guards against N+1 queries when serializing collections with included videos" do
    # Create 3 techniques each with 2 videos (DB-backed)
    create_list(:technique, 3, :with_videos, videos_count: 2)
    techniques =
      Technique.includes(:videos, :technique_type, :belt).limit(3).to_a

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
        techniques,
        include: ["videos"]
      ).to_json
    end

    # Expect a small, bounded number of queries (one for techniques, one for videos, plus minimal overhead)
    expect(queries.size).to be <= 6
  end
end
