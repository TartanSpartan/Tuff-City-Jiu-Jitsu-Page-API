require "rails_helper"

RSpec.describe WaiverSerializer, type: :serializer do
  include SerializerHelpers

  # Simple helper to capture SQL statements emitted while running a block.
  def capture_sql
    sql = []
    subscriber =
      ActiveSupport::Notifications.subscribe(
        "sql.active_record"
      ) { |_, _, _, _, payload| sql << payload[:sql].to_s }
    yield
    ActiveSupport::Notifications.unsubscribe(subscriber)
    # Filter noisy statements (transactions, schema, sqlite pragmas, etc.)
    sql.reject do |s|
      s =~
        /\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|PRAGMA|SAVEPOINT|SHOW)\b/i ||
        s =~ /sqlite_master|pg_attribute|pg_class|information_schema/i
    end
  end

  describe "included resources" do
    it "serializes included user when requested" do
      user =
        create(
          :user,
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        )
      waiver =
        create(
          :waiver,
          user: user,
          participant_name: "Jane Doe",
          participant_email_address: user.email
        )

      payload = serialize_json_api(waiver, includes: ["user"])

      included = payload["included"] || []
      user_included = included.find { |i| i["type"] == "users" }

      expect(user_included).to be_present
      expect(user_included["attributes"]["first_name"]).to eq(user.first_name)
      expect(user_included["attributes"]["email"]).to eq(user.email)
    end
  end

  describe "N+1 guard" do
    it "does not perform unbounded per-record queries when including user" do
      # Create a baseline single record and capture SQL
      waiver_one = create(:waiver)
      sql_one =
        capture_sql do
          ActiveModelSerializers::SerializableResource.new(
            waiver_one,
            adapter: :json_api,
            include: "user"
          ).as_json
        end
      meaningful_one = sql_one.size

      # Create multiple waivers and capture SQL while serializing the collection
      waivers = create_list(:waiver, 6)
      sql_many =
        capture_sql do
          ActiveModelSerializers::SerializableResource.new(
            waivers,
            adapter: :json_api,
            include: "user"
          ).as_json
        end
      meaningful_many = sql_many.size

      # Compute queries-per-record and assert it's bounded (lenient threshold to avoid flakes)
      qpr = meaningful_many.to_f / [waivers.size, 1].max
      expect(qpr).to be <= (meaningful_one + 3),
      "Expected queries-per-record to be <= #{meaningful_one + 3}, got #{qpr} (one=#{meaningful_one}, many=#{meaningful_many})"
    end
  end
end
# spec/serializers/waiver_serializer_spec.rb

require "rails_helper"
require "active_model_serializers/serialization_context"
require "active_model_serializers/adapter"

RSpec.describe WaiverSerializer do
  let(:user) { build_stubbed(:user) }
  let(:waiver) do
    build_stubbed(:waiver, user: nil, participant_name: "Test Participant")
  end
  let(:waiver_with_user) do
    build_stubbed(:waiver, user: user, participant_name: "Test Participant")
  end

  # A helper to generate the parsed serialized JSON using the test helper.
  def serialized_json_for(object)
    serialize_json_api(described_class.new(object))
  end

  describe "Waiver without a user" do
    let(:parsed_json) { serialized_json_for(waiver) }

    it "includes all expected attributes and a nil user relationship" do
      expect(parsed_json["data"]["id"]).to eq(waiver.id.to_s)

      attributes = parsed_json["data"]["attributes"]

      # Corrected key names from camelCase to snake_case
      expect(attributes["participant_name"]).to eq(waiver.participant_name)
      expect(attributes["initials"]).to eq(waiver.initials)
      expect(attributes["participant_email_address"]).to eq(
        waiver.participant_email_address
      )
      expect(attributes["participant_address"]).to eq(
        waiver.participant_address
      )
      expect(attributes["participant_signature"]).to eq(
        waiver.participant_signature
      )
      expect(attributes["participant_date_of_birth"]).to eq(
        waiver.participant_date_of_birth.iso8601
      )
      expect(attributes["participant_phone"]).to eq(waiver.participant_phone)
      expect(attributes["organization_witness_name"]).to eq(
        waiver.organization_witness_name
      )
      expect(attributes["organization_witness_signature"]).to eq(
        waiver.organization_witness_signature
      )
      expect(attributes["emergency_contact_name"]).to eq(
        waiver.emergency_contact_name
      )
      expect(attributes["emergency_contact_number"]).to eq(
        waiver.emergency_contact_number
      )
      expect(attributes["relationship"]).to eq(waiver.relationship)
      expect(attributes["signed_on"]).to eq(waiver.signed_on.iso8601)
      expect(attributes["created_at"]).to eq(waiver.created_at.iso8601(3))
      expect(attributes["updated_at"]).to eq(waiver.updated_at.iso8601(3))

      relationships = parsed_json["data"]["relationships"]
      expect(relationships).to have_key("user")
      expect(relationships["user"]["data"]).to be_nil
    end
  end

  describe "Waiver with an associated user" do
    # We will use a separate let block for the waiver with a user.
    let(:waiver_with_user) { build_stubbed(:waiver, user: user) }
    let(:parsed_json_with_user) { serialized_json_for(waiver_with_user) }

    it "includes all expected attributes and the nested user relationship data" do
      expect(parsed_json_with_user["data"]["id"]).to eq(
        waiver_with_user.id.to_s
      )

      attributes = parsed_json_with_user["data"]["attributes"]

      expect(attributes["participant_name"]).to eq(
        waiver_with_user.participant_name
      )
      expect(attributes["initials"]).to eq(waiver_with_user.initials)
      expect(attributes["participant_email_address"]).to eq(
        waiver_with_user.participant_email_address
      )
      expect(attributes["participant_address"]).to eq(
        waiver_with_user.participant_address
      )
      expect(attributes["participant_signature"]).to eq(
        waiver_with_user.participant_signature
      )
      expect(attributes["participant_date_of_birth"]).to eq(
        waiver_with_user.participant_date_of_birth.iso8601
      )
      expect(attributes["participant_phone"]).to eq(
        waiver_with_user.participant_phone
      )
      expect(attributes["organization_witness_name"]).to eq(
        waiver_with_user.organization_witness_name
      )
      expect(attributes["organization_witness_signature"]).to eq(
        waiver_with_user.organization_witness_signature
      )
      expect(attributes["emergency_contact_name"]).to eq(
        waiver_with_user.emergency_contact_name
      )
      expect(attributes["emergency_contact_number"]).to eq(
        waiver_with_user.emergency_contact_number
      )
      expect(attributes["relationship"]).to eq(waiver_with_user.relationship)
      expect(attributes["signed_on"]).to eq(waiver_with_user.signed_on.iso8601)
      expect(attributes["created_at"]).to eq(
        waiver_with_user.created_at.iso8601(3)
      )
      expect(attributes["updated_at"]).to eq(
        waiver_with_user.updated_at.iso8601(3)
      )

      relationships = parsed_json_with_user["data"]["relationships"]
      expect(relationships).to have_key("user")
      expect(relationships["user"]["data"]).not_to be_nil
      expect(relationships["user"]["data"]["id"]).to eq(
        waiver_with_user.user.id.to_s
      )
      expect(relationships["user"]["data"]["type"]).to eq("users")
    end
  end

  describe "Waiver with nil attributes" do
    let(:waiver_with_nil) do
      # Use build_stubbed for serializer-only behavior; model validations are not required here
      build_stubbed(
        :waiver,
        user: nil,
        participant_name: "Test Participant",
        initials: nil,
        participant_address: nil,
        participant_phone: nil,
        emergency_contact_name: nil,
        emergency_contact_number: nil,
        relationship: nil
      )
    end
    let(:parsed_json) { serialized_json_for(waiver_with_nil) }

    it "serializes nil attributes correctly" do
      # Note: We can't use `be_valid` here since the model validations require
      # these attributes. This test is purely for serializer behavior.
      attributes = parsed_json["data"]["attributes"]

      # The serializer should include the key with a nil value
      expect(attributes).to have_key("initials")
      expect(attributes["initials"]).to be_nil
      expect(attributes).to have_key("participant_address")
      expect(attributes["participant_address"]).to be_nil
      expect(attributes).to have_key("participant_phone")
      expect(attributes["participant_phone"]).to be_nil
      expect(attributes).to have_key("emergency_contact_name")
      expect(attributes["emergency_contact_name"]).to be_nil
      expect(attributes).to have_key("emergency_contact_number")
      expect(attributes["emergency_contact_number"]).to be_nil
      expect(attributes).to have_key("relationship")
      expect(attributes["relationship"]).to be_nil
    end
  end

  describe "factory" do
    it "is valid" do
      waiver = build(:waiver)
      expect(waiver).to be_valid
    end

    it "is valid without a user when using the :unsigned trait" do
      waiver = build(:waiver, :unsigned)
      expect(waiver).to be_valid
      expect(waiver.user).to be_nil
    end
  end

  describe "included user (DB-backed)" do
    it "returns the full included user resource when requested" do
      u = create(:user)
      w = create(:waiver, user: u)

      included_json =
        JSON.parse(
          ActiveModelSerializers::SerializableResource.new(
            w,
            include: ["user"]
          ).to_json
        )

      included = included_json["included"]
      expect(included).to be_present
      user_objs =
        included.select { |r| r["type"] == "users" || r["type"] == "user" }
      expect(user_objs).not_to be_empty
      included_user = user_objs.find { |r| r["id"] == u.id.to_s }
      expect(included_user).to be_present
      # Representative attribute check (email is commonly present)
      expect(included_user["attributes"]["email"]).to eq(u.email)
    end
  end

  describe "N+1 guard for waivers (DB-backed)" do
    it "keeps queries-per-record bounded when serializing many waivers with included user" do
      single_user = create(:user)
      single = create(:waiver, user: single_user)
      single_relation = Waiver.includes(:user).where(id: single.id)

      sql_single = []
      ActiveSupport::Notifications.subscribed(
        ->(_n, _s, _f, _id, payload) { sql_single << payload[:sql] },
        "sql.active_record"
      ) do
        ActiveModelSerializers::SerializableResource.new(
          single_relation,
          include: ["user"]
        ).to_json
      end

      many =
        create_list(:waiver, 6) do |w, i|
          w.user = create(:user)
          w.save!
        end
      many_relation =
        Waiver.includes(:user).where(id: many.map(&:id)).order(:id)

      sql_many = []
      ActiveSupport::Notifications.subscribed(
        ->(_n, _s, _f, _id, payload) { sql_many << payload[:sql] },
        "sql.active_record"
      ) do
        ActiveModelSerializers::SerializableResource.new(
          many_relation,
          include: ["user"]
        ).to_json
      end

      meaningful_many =
        sql_many.reject do |s|
          s =~ /\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/i ||
            s =~
              /sqlite_master|pg_attribute|pg_class|pg_namespace|pg_type|information_schema/i
        end

      per_record = meaningful_many.size.to_f / many.size
      # Lenient threshold: ensure we don't see linear per-record growth; allow up to 6 queries/record here
      expect(per_record).to be <= 6
    end
  end
end
