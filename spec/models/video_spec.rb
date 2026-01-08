# frozen_string_literal: true

require "rails_helper"

RSpec.describe Video, type: :model do
  # Using Factory Bot to create a valid video instance for testing.
  # The `let` block ensures this is lazy-loaded and only created when used.
  let(:video) { FactoryBot.build(:video) }

  # --- Associations ---
  describe "associations" do
    it "belongs to a technique" do
      # Checks if the `belongs_to` association with Technique is correctly defined.
      expect(video).to belong_to(:technique)
    end
  end

  # --- Validations ---
  describe "validations" do
    context "with valid attributes" do
      it "is valid with valid attributes" do
        expect(video).to be_valid
      end
    end

    context "with invalid attributes" do
      it "is not valid without a url" do
        video.url = nil
        expect(video).not_to be_valid
      end

      it "is not valid with a duplicate url" do
        # We explicitly create every parent object to prevent FactoryBot from creating duplicates.

        # 1. Create a single, non-conflicting syllabus.
        unique_syllabus = create(:syllabus, country: "NZ", year: 2024)

        # 2. Create the associated objects, explicitly linking them to the unique syllabus.
        unique_belt = create(:belt, syllabus: unique_syllabus)
        unique_technique_type =
          create(:technique_type, syllabus: unique_syllabus, belt: unique_belt)

        # 3. Create the technique, explicitly linking all its associations to avoid
        # FactoryBot's implicit creation of new syllabi.
        unique_technique =
          create(
            :technique,
            belt: unique_belt,
            technique_type: unique_technique_type
          )

        # 4. Create the first video, explicitly linking it to our unique technique.
        create(
          :video,
          url: "https://www.youtube.com/watch?v=unique_test_id",
          technique: unique_technique
        )

        # 5. Build the second video with the same unique URL and the same technique.
        # This is the record we expect to be invalid due to the uniqueness validation.
        new_video =
          build(
            :video,
            url: "https://www.youtube.com/watch?v=unique_test_id",
            technique: unique_technique
          )

        # This assertion should now pass.
        expect(new_video).not_to be_valid
      end

      it "is not valid without a country" do
        video.country = nil
        expect(video).not_to be_valid
      end

      it "is not valid without a year" do
        video.year = nil
        expect(video).not_to be_valid
      end

      it "is not valid with a year less than or equal to 1900" do
        video.year = 1900
        expect(video).not_to be_valid
      end

      it "is not valid with a non-integer year" do
        video.year = 2012.5
        expect(video).not_to be_valid
      end

      it "is not valid with a year in the future" do
        video.year = Date.today.year + 1
        expect(video).not_to be_valid
      end

      it "is not valid without a technique" do
        video.technique = nil
        expect(video).not_to be_valid
      end
    end

    context "url normalization and youtube variants" do
      it "normalizes youtu.be short links to canonical watch URL" do
        v = create(:video, url: "https://youtu.be/shortTest123")
        expect(v.url).to eq("https://www.youtube.com/watch?v=shortTest123")
      end

      it "normalizes embed URLs to canonical watch URL" do
        v = create(:video, url: "https://www.youtube.com/embed/embedVid456")
        expect(v.url).to eq("https://www.youtube.com/watch?v=embedVid456")
      end

      it "strips surrounding whitespace and normalizes" do
        v = create(:video, url: "  https://www.youtube.com/watch?v=spaceVid  ")
        expect(v.url).to eq("https://www.youtube.com/watch?v=spaceVid")
      end
    end

    context "url negative validation cases" do
      it "rejects non-YouTube URLs" do
        bad = build(:video, url: "http://example.com/notyoutube")
        expect(bad).not_to be_valid
        expect(bad.errors[:url]).to include("must be a YouTube URL")
      end

      it "normalizes YouTube URLs supplied with other schemes into https canonical form" do
        v = create(:video, url: "ftp://www.youtube.com/watch?v=abcde")
        expect(v.url).to eq("https://www.youtube.com/watch?v=abcde")
      end

      it "rejects URLs that do not contain a plausible video id" do
        bad = build(:video, url: "https://www.youtube.com/watch?v=ab")
        expect(bad).not_to be_valid
        expect(bad.errors[:url]).to include(
          "does not contain a valid YouTube video id"
        )
      end
    end

    context "year boundary checks" do
      it "rejects 1900 as invalid" do
        video.year = 1900
        expect(video).not_to be_valid
      end

      it "accepts 1901 as valid" do
        video.year = 1901
        expect(video).to be_valid
      end

      it "accepts the current year" do
        video.year = Date.today.year
        expect(video).to be_valid
      end

      it "rejects next year and shows explicit message" do
        next_year = Date.today.year + 1
        video.year = next_year
        expect(video).not_to be_valid
        expect(video.errors[:year]).to include(
          "can't be in the future (must be <= #{Date.today.year})"
        )
      end
    end
  end
end
