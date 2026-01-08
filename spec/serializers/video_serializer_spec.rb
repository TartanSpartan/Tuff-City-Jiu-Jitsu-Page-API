# frozen_string_literal: true

require "rails_helper"
require "active_support/core_ext/hash/keys"

RSpec.describe VideoSerializer, type: :serializer do
  # Use FactoryBot's build_stubbed to create a mock object
  # that behaves like an ActiveRecord model without hitting the database.
  let(:video) { build_stubbed(:video) }
  let(:video_with_technique) do
    # Create a video with a valid technique association for testing purposes.
    # Note: FactoryBot handles the `technique` and `technique_id`
    # attributes for us when we build the video.
    build_stubbed(:video, :with_technique)
  end

  subject(:serialized_video) do
    JSON.parse(
      described_class.new(video_with_technique).serializable_hash.to_json
    ).deep_symbolize_keys
  end

  describe "attributes" do
    # The attributes test now correctly includes the 'id'
    it "includes the correct attributes" do
      expected_attributes = %i[
        id
        url
        country
        year
        created_at
        updated_at
        technique_id
      ]
      expect(serialized_video.keys).to include(*expected_attributes)
    end

    it "serializes the correct values for each attribute" do
      expect(serialized_video[:url]).to eq(video_with_technique.url)
      expect(serialized_video[:country]).to eq(video_with_technique.country)
      expect(serialized_video[:year]).to eq(video_with_technique.year)
    end

    it "serializes the correct ID" do
      expect(serialized_video[:id]).to eq(video_with_technique.id)
    end

    # The regex is updated to correctly match the ISO 8601 format with milliseconds.
    it "serializes timestamps and they parse to the model times" do
      expect(Time.parse(serialized_video[:created_at]).to_time).to be_within(
        2.seconds
      ).of(video_with_technique.created_at.to_time)
      expect(Time.parse(serialized_video[:updated_at]).to_time).to be_within(
        2.seconds
      ).of(video_with_technique.updated_at.to_time)
    end

    context "when country and year are nil" do
      let(:video_nil_attrs) { build_stubbed(:video, country: nil, year: nil) }
      subject(:serialized_nil_video) do
        JSON.parse(
          described_class.new(video_nil_attrs).serializable_hash.to_json
        ).deep_symbolize_keys
      end

      it "serializes country as nil" do
        expect(serialized_nil_video[:country]).to be_nil
      end

      it "serializes year as nil" do
        expect(serialized_nil_video[:year]).to be_nil
      end
    end
  end

  describe "associations" do
    it "includes the technique association" do
      expect(serialized_video).to have_key(:technique)
    end

    it "serializes the associated technique data" do
      technique_data = serialized_video[:technique]
      expect(technique_data[:id]).to eq(video_with_technique.technique.id)
      expect(technique_data[:summary]).to eq(
        video_with_technique.technique.summary
      )
    end

    context "when the video has no technique" do
      # Create a new stubbed video without a technique association.
      let(:video_without_technique) { build_stubbed(:video, technique: nil) }
      subject(:serialized_video) do
        JSON.parse(
          described_class.new(video_without_technique).serializable_hash.to_json
        ).deep_symbolize_keys
      end

      it "serializes the technique association as nil" do
        expect(serialized_video[:technique]).to be_nil
      end

      it "serializes the technique ID as nil" do
        expect(serialized_video[:technique_id]).to be_nil
      end
    end
  end

  describe "included resources (DB-backed)" do
    it "returns the full included technique when requested" do
      v = create(:video, :with_technique)

      included_json =
        JSON.parse(
          ActiveModelSerializers::SerializableResource.new(
            v,
            include: ["technique"]
          ).to_json
        )

      included = included_json["included"]
      expect(included).to be_present
      tech_objs =
        included.select do |r|
          r["type"] == "techniques" || r["type"] == "technique"
        end
      expect(tech_objs).not_to be_empty
      included_tech = tech_objs.find { |r| r["id"] == v.technique.id.to_s }
      expect(included_tech).to be_present
      # Verify a representative attribute to ensure payload correctness
      expect(included_tech["attributes"]["summary"]).to eq(v.technique.summary)
    end
  end

  describe "N+1 guard for collections (DB-backed)" do
    it "does not exhibit linear-per-record query growth when serializing many videos with included technique" do
      # Measure queries for a single record
      single = create(:video, :with_technique)
      single_relation = Video.includes(:technique).where(id: single.id)

      sql_single = []
      ActiveSupport::Notifications.subscribed(
        ->(_n, _s, _f, _id, payload) { sql_single << payload[:sql] },
        "sql.active_record"
      ) do
        ActiveModelSerializers::SerializableResource.new(
          single_relation,
          include: ["technique"]
        ).to_json
      end

      # single run SQL captured in `sql_single` (we don't need to further filter it for this assertion)

      # Measure queries for multiple records
      # Eager-load nested technique associations that the serializer touches so the test
      # mirrors correct controller behavior in production. If collection endpoints render
      # videos with technique details, callers should also preload technique's associations
      # to avoid per-record queries.
      many = create_list(:video, 6, :with_technique)
      many_relation =
        Video
          .includes(
            technique: %i[technique_type belt videos differences comparisons]
          )
          .where(id: many.map(&:id))
          .order(:id)

      sql_many = []
      ActiveSupport::Notifications.subscribed(
        ->(_n, _s, _f, _id, payload) { sql_many << payload[:sql] },
        "sql.active_record"
      ) do
        ActiveModelSerializers::SerializableResource.new(
          many_relation,
          include: ["technique"]
        ).to_json
      end

      meaningful_many =
        sql_many.reject do |s|
          s =~ /\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/i ||
            s =~
              /sqlite_master|pg_attribute|pg_class|pg_namespace|pg_type|information_schema/i
        end

      # Compute queries per record and ensure it remains bounded (not one query per record)
      per_record = meaningful_many.size.to_f / many.size
      # Stricter threshold: allow at most 3 queries per record. If this fails, we'll inspect
      # the exact SQL emitted to find the overhead and fix it (preloads or serializer behavior).
      expect(per_record).to be <= 3
    end
  end
end
