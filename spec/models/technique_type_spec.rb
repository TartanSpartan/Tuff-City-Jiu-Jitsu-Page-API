require "rails_helper"

# We use describe blocks to organize our tests for clarity.
# The 'type: :model' part tells RSpec that this is a model spec.
RSpec.describe TechniqueType, type: :model do
  # Build a valid TechniqueType instance with associations for validation tests
  subject { build(:technique_type) }
  # The 'shoulda-matchers' gem provides these single-line matchers
  # to make tests for associations and validations very readable.

  describe "Associations" do
    # This now correctly tests for a required syllabus association.
    it { should belong_to(:syllabus).required(true) }

    # The `optional(true)` flag has been removed, so this test now
    # correctly expects a belt to be present for a valid record.
    it { should belong_to(:belt) }

    # `has_many` confirms the one-to-many relationship to techniques.
    it { should have_many(:techniques) }
  end

  describe "Validations" do
    # `validate_presence_of` checks that the model requires a value for the specified attribute.
    it { should validate_presence_of(:category) }
    it "allows sub_category to be blank (optional classification)" do
      expect(build(:technique_type, sub_category: nil)).to be_valid
    end

    context "length and uniqueness behavior" do
      it "enforces a maximum length on sub_category" do
        long = "a" * 256
        tt = build(:technique_type, sub_category: long)
        expect(tt).to be_invalid
        expect(tt.errors[:sub_category]).not_to be_empty
      end

      it "is unique for the tuple (syllabus, belt, category, sub_category) when sub_category is present" do
        first = create(:technique_type, sub_category: "Arms", category: "Sweep")
        dup =
          build(
            :technique_type,
            sub_category: "Arms",
            category: first.category,
            syllabus: first.syllabus,
            belt: first.belt
          )
        expect(dup).to be_invalid
        # Validate to populate errors
        dup.validate
        expect(dup.errors[:sub_category]).to include(
          a_string_matching(/taken|unique/)
        )
      end

      it "does not run the uniqueness validation for empty-string sub_category (allow_blank behavior)" do
        first = create(:technique_type, sub_category: "")

        dup =
          build(
            :technique_type,
            sub_category: "",
            category: first.category,
            syllabus: first.syllabus,
            belt: first.belt
          )

        # Model-level uniqueness validation is configured with `allow_blank: true`.
        # That means an empty string is treated as blank for the purposes of the
        # validation and the model will consider this valid. The DB-level partial
        # unique index (which only ignores NULL) is responsible for preventing
        # duplicate non-NULL values like an empty string.
        expect(dup).to be_valid
      end

      it "allows multiple records with NULL/blank sub_category for the same syllabus/belt/category" do
        first = create(:technique_type, sub_category: nil, category: "Position")
        other =
          build(
            :technique_type,
            sub_category: nil,
            category: first.category,
            syllabus: first.syllabus,
            belt: first.belt
          )
        expect(other).to be_valid
      end
    end

    it "capitalizes the first letter of the category on save" do
      tt = create(:technique_type, category: "bunkai")
      expect(tt.category).to eq("Bunkai")
    end
  end

  describe "cache warming callbacks" do
    let(:syllabus) { create(:syllabus) }
    let(:belt) { create(:belt, syllabus: syllabus) }

    it "enqueues WarmSyllabusCacheJob on create" do
      expect(WarmSyllabusCacheJob).to receive(:perform_later).with(syllabus.id).at_least(:once)

      create(:technique_type, syllabus: syllabus, belt: belt)
    end

    it "enqueues WarmSyllabusCacheJob on update" do
      technique_type = create(:technique_type, syllabus: syllabus, belt: belt)

      expect(WarmSyllabusCacheJob).to receive(:perform_later).with(syllabus.id).at_least(:once)

      technique_type.update(category: "Updated Category")
    end

    it "enqueues WarmSyllabusCacheJob on destroy" do
      technique_type = create(:technique_type, syllabus: syllabus, belt: belt)

      expect(WarmSyllabusCacheJob).to receive(:perform_later).with(syllabus.id).at_least(:once)

      technique_type.destroy
    end
  end
end
