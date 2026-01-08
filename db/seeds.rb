# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

PASSWORD = "justinbailey" # Inspired by a classic video game password; let's change this, encrypt it/hide it from Github at some point (recommneded to use a .env file built for Rails) and subsequently audit the whole file (however this will certainly not be the password in production mode!).

User.delete_all
Belt.delete_all
BeltGrade.delete_all
Qualification.delete_all
InstructorQualification.delete_all
TechniqueType.delete_all
Technique.delete_all
Video.delete_all
Syllabus.delete_all

require "securerandom"

# Helper to create videos in seeds with unique dummy URLs and a sensible default year
def create_seed_video(attrs)
  a = attrs.dup
  a[:url] = a[:url].to_s.strip
  # Ensure URL uniqueness for seed data
  if a[:url].empty? || Video.exists?(url: a[:url])
    a[:url] = "dummy://#{SecureRandom.uuid}"
  end
  # Ensure a numeric year is present; pick by country if absent
  unless a.key?(:year) && a[:year]
    a[:year] = if a[:country].to_s.downcase.include?("uk") ||
         a[:country].to_s.downcase.include?("britain")
      2011
    else
      2021
    end
  end
  # Accept either a Technique object or an id for technique association
  if a.key?(:technique_id) && a[:technique_id].respond_to?(:id)
    a[:technique_id] = a[:technique_id].id
  end
  Video.create!(a)
end

syllabus_canada_2021 =
  Syllabus.create!(
    country: "canada",
    year: "2021",
    is_primary_admin_syllabus: false,
    is_secondary_admin_syllabus: true
  ) # This is the most recent iteration of the Canadian syllabus
syllabus_britain_2011 =
  Syllabus.create!(
    country: "uk",
    year: "2011",
    is_primary_admin_syllabus: true,
    is_secondary_admin_syllabus: false
  ) # This is an earlier iteration of the British syllabus, one which Seumas and David were familiar with before they left for Canada

first_aid_qualifications = "First Aid & CPR" # Here we assume that a user will qualify for both First Aid and CPR simultaneously; therefore no need for an array, a string is sufficient
# Other rules which define grading criteria in Canada: a green belt going for purple belt needs Assistant Instructor qualification, a light blue going for dark blue needs Instructor, a dark blue
# going for brown needs first aid and CPR, a brown going for dan must have Club Instructor. Also, first aid + CPR needs to be renewed every so many years and should go inactive here as in real life.
# A student's first aid expiry date can be verfied from the certificate they offer to the club instructors to prove that they are suitably qualified.

# When considering pseudocode for this, we should presume that any member, even a beginner white belt can have a first aid qualification obtained for whatever reason (in or out of martial
# arts), or may not, so they can randomly be assigned one. Also, we do not expect beginners to have instructor qualifications, so we can randomly assign Assistant Instructor to orange belts
# at the earliest. Then Instructor to purple at the earliest, then Club Instructor to dark blue at the earliest (they have been mandated to teach solo in this fashion, before). This is all
# arbitrary and theoretical, but based on sound logic, and these users will be replaced by real ones in due course.

kyu_grade_array = [
  "brown",
  "dark blue",
  "light blue",
  "purple",
  "green",
  "orange",
  "yellow",
  "white"
] # These are the "kyu" grades, the coloured belts below black belt.
# This reverse order list means that brown will have a belt_id of 1 which matches how it is officially designated as 1st Kyu, and so on going down the ladder.
dan_grade_array = %w[shodan nidan sandan] # These latter three grades are not colours, but types of black belt or "dan" grade.
# As there are no dan/black belt grades in the club yet, we will just include that array for later when we do have them.

CANADIAN_2021_BELT_MAP = {}
UK_2011_BELT_MAP = {}

kyu_grade_array.each_with_index do |colour, index| # Map to the belts required for the Canadian 2021 syllabus
  # Kyu numbers start at 1 for the highest kyu grade (brown)
  kyu_num = index + 1
  canadian_2021_belt =
    Belt.create!(
      {
        colour: colour,
        syllabus_id: syllabus_canada_2021.id,
        kyu_number: kyu_num
      }
    )
  CANADIAN_2021_BELT_MAP[colour] = canadian_2021_belt
end

kyu_grade_array.each_with_index do |colour, index| # Map to the belts required for the UK 2011 syllabus
  # Kyu numbers start at 1 for the highest kyu grade (brown)
  kyu_num = index + 1
  uk_2011_belt =
    Belt.create!(
      {
        colour: colour,
        syllabus_id: syllabus_britain_2011.id,
        kyu_number: kyu_num
      }
    )
  UK_2011_BELT_MAP[colour] = uk_2011_belt
end

# Define constants for logic used in the random user loop below, for Canada
CANADIAN_BROWN_KYU = CANADIAN_2021_BELT_MAP["brown"].kyu_number # 1
CANADIAN_DARK_BLUE_KYU = CANADIAN_2021_BELT_MAP["dark blue"].kyu_number # 2
CANADIAN_LIGHT_BLUE_KYU = CANADIAN_2021_BELT_MAP["light blue"].kyu_number # 3
CANADIAN_PURPLE_KYU = CANADIAN_2021_BELT_MAP["purple"].kyu_number # 4

# Define constants for logic used in the random user loop below, for the UK
UK_BROWN_KYU = UK_2011_BELT_MAP["brown"].kyu_number # 1
UK_DARK_BLUE_KYU = UK_2011_BELT_MAP["dark blue"].kyu_number # 2
UK_LIGHT_BLUE_KYU = UK_2011_BELT_MAP["light blue"].kyu_number # 3
UK_PURPLE_KYU = UK_2011_BELT_MAP["purple"].kyu_number # 4

QUALIFICATION_LEVELS = [
  "No qualifications",
  "Assistant instructor",
  "Instructor",
  "Club instructor"
] # A user member can only have one of these "active" at a time, and each successive one supplants the last.

INSTRUCTOR_QUAL_LEVEL_INDEX = QUALIFICATION_LEVELS.index("Instructor") # 2

canadian_2021_belts_requiring_instructor_qualifications_array = [
  CANADIAN_2021_BELT_MAP["green"].id,
  CANADIAN_2021_BELT_MAP["light blue"].id,
  CANADIAN_2021_BELT_MAP["brown"].id
] # Here this denotes for which grades a user requires an instructor qualification to be able to grade to the next one up: green, light blue and brown.

# We'll also create a dummy qualification for white belts just so this can be instantiated on user sign up

# 2. Create Qualification records by mapping qualification level directly to belt colour
CANADIAN_QUALIFICATION_BELT_MAPPING = {
  "No qualifications" => "white",
  "Assistant instructor" => "green",
  "Instructor" => "light blue",
  "Club instructor" => "brown"
}

UK_QUALIFICATION_BELT_MAPPING = {
  "No qualifications" => "white",
  "Assistant instructor" => "green",
  "Instructor" => "light blue",
  "Club instructor" => "brown"
}

CANADIAN_QUALIFICATION_BELT_MAPPING.each do |level, belt_colour|
  # Use .fetch here to ensure the required belt actually exists in CANADIAN_2021_BELT_MAP
  belt =
    CANADIAN_2021_BELT_MAP.fetch(belt_colour) do
      raise "FATAL ERROR: Required belt '#{belt_colour}' not found. Check BELT_MAP creation."
    end
  Qualification.create!({ belt: belt, level: level })
end

UK_QUALIFICATION_BELT_MAPPING.each do |level, belt_colour|
  # Use .fetch here to ensure the required belt actually exists in UK_2011_BELT_MAP
  belt =
    UK_2011_BELT_MAP.fetch(belt_colour) do
      raise "FATAL ERROR: Required belt '#{belt_colour}' not found. Check BELT_MAP creation."
    end
  Qualification.create!({ belt: belt, level: level })
end

# Pre-load Qualifications Map for efficient lookup in the loop
QUALIFICATIONS_MAP = Qualification.all.index_by(&:level)

# Sanity check and pre-fetch for manual user creation
club_instructor_qualification_record =
  QUALIFICATIONS_MAP.fetch("Club instructor")
instructor_qualification_record = QUALIFICATIONS_MAP.fetch("Instructor")
assistant_instructor_qualification_record =
  QUALIFICATIONS_MAP.fetch("Assistant instructor")
no_qualification_record = QUALIFICATIONS_MAP.fetch("No qualifications")

# Now, to create the users and their required associated data entities
# 1. Seumas (Admin)
admin_user =
  User.create!(
    first_name: "Seumas",
    last_name: "Finlayson",
    email: "seumasfinlayson@googlemail.com",
    password: PASSWORD,
    password_confirmation: PASSWORD,
    is_admin: true,
    dues_paid: true,
    owns_gi: true,
    has_first_aid_qualification: true,
    first_aid_achievement_date: Date.new(2020, 11, 22),
    first_aid_expiry_date: Date.new(2023, 11, 22)
  )
admin_user.syllabi << syllabus_canada_2021

# First, we set the qualifications and belt grades for the real users Seumas and David

# Seumas's Instructor Qualification (Club Instructor)
siq_canada =
  InstructorQualification.create!(
    {
      user: admin_user,
      # qualification_id: QUALIFICATIONS_MAP["Club Instructor"].id,
      qualification: club_instructor_qualification_record,
      achieved_at: Date.new(2016, 12, 03),
      belt_grade: nil,
      belt: CANADIAN_2021_BELT_MAP["brown"]
    }
  )

# Seumas's BeltGrade (Brown Belt) in Canada
sbg_canada =
  BeltGrade.create!(
    user: admin_user,
    belt: CANADIAN_2021_BELT_MAP["brown"], # Seumas, user_id:1, is a 1st Kyu so this id codifies his brown belt
    obtained_at: Date.new(2016, 12, 15) # Double check the exact date
  )

# Link the qualification back to the grade to complete the association
siq_canada.update!(belt_grade: sbg_canada)

# Seumas must also have a UK BeltGrade to ensure that he can view the British syllabus (actually this may not be required!)
# uk_sbg = BeltGrade.create!(
#     user: admin_user,
#     belt: UK_2011_BELT_MAP["brown"], # Use the corresponding UK Belt record
#     obtained_at: Date.new(2016, 12, 15)
# )

# 2. David (Instructor)
instructor_user =
  User.create!(
    first_name: "David",
    last_name: "Corbett",
    email: "tuffcityjitsu@gmail.com",
    password: PASSWORD,
    password_confirmation: PASSWORD,
    is_admin: true,
    dues_paid: true,
    owns_gi: true,
    has_first_aid_qualification: true,
    first_aid_achievement_date: Date.new(2020, 11, 22),
    first_aid_expiry_date: Date.new(2023, 11, 22)
  )
instructor_user.syllabi << syllabus_canada_2021

# David's Instructor Qualification (Club Instructor)
diq =
  InstructorQualification.create!(
    {
      user: instructor_user,
      qualification: club_instructor_qualification_record,
      achieved_at: Date.new(2017, 12, 03),
      belt_grade: nil, # Temporarily set to nil
      belt: CANADIAN_2021_BELT_MAP["purple"]
    }
  )

# David's BeltGrade (Purple Belt)
dbg =
  BeltGrade.create!(
    user: instructor_user,
    belt: CANADIAN_2021_BELT_MAP["purple"],
    obtained_at: Date.new(2017, 06, 20) # Double check the exact date
  )

# Link the qualification back to the grade to complete the association
diq.update!(belt_grade: dbg)

# And now we create 20 random users with random data (within the constraints which each belt grade imposes)

puts "Creating 20 random users (in addition to 2 manual users) and their grades/qualifications..."
20.times do
  canadian_2021_belts = Belt.all
  canadian_2021_belt = canadian_2021_belts.sample
  canadian_2021_belt_kyu = canadian_2021_belt.kyu_number

  # 1. Generate User attributes
  first_name = Faker::Name.first_name
  last_name = Faker::Name.last_name

  # Brown Belt (Kyu 1) MUST have First Aid/CPR to pass validation
  if canadian_2021_belt_kyu == CANADIAN_BROWN_KYU
    has_first_aid_qualification = true
  else
    # All other belts can randomly have it or not
    has_first_aid_qualification = [true, false].sample
  end

  if has_first_aid_qualification == true
    # Ensure the date is still valid (expiry in the future)
    first_aid_achievement_date = Faker::Date.backward(days: 365 * 1)
    first_aid_expiry_date = Faker::Date.forward(days: 365 * 2)
  else
    first_aid_achievement_date = nil
    first_aid_expiry_date = nil
  end

  # 2. Create and Save the User
  u =
    User.create!(
      {
        first_name: first_name,
        last_name: last_name,
        email: "#{first_name.downcase}.#{last_name.downcase}@usermail.com",
        password: PASSWORD,
        password_confirmation: PASSWORD,
        dues_paid: true, # They must at least soon after signing up have their dues paid to be a regularly training member of the club
        owns_gi: true, # Ditto as with dues_paid
        has_first_aid_qualification: has_first_aid_qualification,
        first_aid_achievement_date: first_aid_achievement_date,
        first_aid_expiry_date: first_aid_expiry_date
      }
    )

  # 3. Associate Syllabus
  u.syllabi << syllabus_canada_2021

  # 4a. Determine Minimum Required Qualification Index based on Kyu grade
  min_qual_index = 0 # Default: "No qualifications"

  if canadian_2021_belt_kyu == CANADIAN_BROWN_KYU # Kyu 1 (Brown)
    min_qual_index = QUALIFICATION_LEVELS.index("Club instructor") # 3
  elsif canadian_2021_belt_kyu == CANADIAN_DARK_BLUE_KYU # Kyu 2 (Dark Blue)
    min_qual_index = QUALIFICATION_LEVELS.index("Instructor") # 2
  elsif canadian_2021_belt_kyu == CANADIAN_LIGHT_BLUE_KYU ||
        canadian_2021_belt_kyu == CANADIAN_PURPLE_KYU # Kyu 3 (Light Blue) or Kyu 4 (Purple)
    min_qual_index = QUALIFICATION_LEVELS.index("Assistant instructor") # 1
  end

  # 4b. Randomly select a Qualification level that is EQUAL TO or HIGHER than the minimum required
  # This prevents the validation error by ensuring a high belt always has a valid qualification choice.
  valid_qual_levels = QUALIFICATION_LEVELS[min_qual_index..-1]
  qualification_level = valid_qual_levels.sample

  # 4c. Set achieved_at
  achieved_at = Faker::Date.backward(days: 365 * 1)
  achieved_at = nil if qualification_level == "No qualifications"

  qualification = QUALIFICATIONS_MAP.fetch(qualification_level)

  # 5. Create InstructorQualification first (always, including "No qualifications")
  # We persist a baseline record so `current_instructor_qualification` is never null.
  created_iq =
    InstructorQualification.create!(
      {
        user: u,
        qualification: qualification,
        # For "No qualifications", achieved_at must be nil per validations; otherwise use generated date
        achieved_at: (qualification.level == "No qualifications" ? nil : achieved_at),
        belt_grade: nil, # Temporarily set to nil; linked after BeltGrade creation
        belt: canadian_2021_belt
      }
    )

  # 6. Create BeltGrade (This will now validate correctly against the existing InstructorQualification)
  bg =
    BeltGrade.create!(
      {
        user: u,
        belt: canadian_2021_belt,
        obtained_at: Faker::Date.backward(days: 365 * 2)
      }
    )

  # 7. Link the qualification back to the grade
  created_iq.update!(belt_grade: bg) if created_iq.present?
end

# Now for "boilerplate" technique types for formatting
yellow_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  ) # Dummy Waza category which will have no techniques at yellow and read "All previous syllabus" for all subsequent grades
orange_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
purple_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["purple"].id,
    syllabus_id: syllabus_canada_2021.id
  )
light_blue_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["light blue"].id,
    syllabus_id: syllabus_canada_2021.id
  )
dark_blue_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["dark blue"].id,
    syllabus_id: syllabus_canada_2021.id
  )
brown_canadian_waza =
  TechniqueType.create!(
    category: "Waza (techniques)",
    sub_category: "All previous syllabus",
    belt_id: CANADIAN_2021_BELT_MAP["brown"].id,
    syllabus_id: syllabus_canada_2021.id
  )

yellow_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  ) # Dummy category which is just a bit of formatting sugar for the syllabus: a whole lot of tilda characters!
orange_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
purple_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["purple"].id,
    syllabus_id: syllabus_canada_2021.id
  )
light_blue_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["light blue"].id,
    syllabus_id: syllabus_canada_2021.id
  )
dark_blue_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["dark blue"].id,
    syllabus_id: syllabus_canada_2021.id
  )
brown_canadian_tildas =
  TechniqueType.create!(
    category: "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~",
    sub_category: "Blank",
    belt_id: CANADIAN_2021_BELT_MAP["brown"].id,
    syllabus_id: syllabus_canada_2021.id
  )

tt =
  TechniqueType.create(
    category: "This is a technique type of Ukemi category",
    sub_category: "And of subcategory standing roll",
    syllabus_id: syllabus_canada_2021.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  ) # More boilerplate, to be substantiated later for ALL technique types (and then all techniques and videos in turn)

t =
  Technique.create(
    summary:
      "This is a white belt technique of Ukemi technique type: a standing sideways roll",
    technique_type_id: tt.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  ) # Draw the required IDs from that aformentioned Technique Type and yellow belt

v =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    year: 2021,
    technique_id: t.id
  ) # Videos are now reintegrated into the platform, but their URLs must be sourced (and if some URLs don't yet exist, then they must be filmed) and built out here

# Now for actual technique types interspersed with their related techniques (which in time will be acccompanied by URLs for videos)
yellow_canadian_2021_kneeling_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Kneeling falling",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_kneeling_falling_technique =
  Technique.create!(
    summary: "Ukemi-no-kata (kneeling)",
    technique_type_id: yellow_canadian_2021_kneeling_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_kneeling_falling_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_kneeling_falling_technique.id
  )

yellow_british_2011_kneeling_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Kneeling falling",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_kneeling_falling_technique =
  Technique.create!(
    summary: "Kneeling Forwards Backwards Sideways",
    technique_type_id: yellow_british_2011_kneeling_ukemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kneeling_falling_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kneeling_falling_technique.id
  )

yellow_canadian_2021_standing_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Standing falling",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_standing_static_sideways_technique =
  Technique.create!(
    summary: "Standing sideways rolls (into kamae)",
    technique_type_id: yellow_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_standing_static_sideways_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_standing_static_sideways_technique.id
  )
yellow_canadian_2021_pegleg_technique =
  Technique.create!(
    summary: "Peg-leg break-fall",
    technique_type_id: yellow_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_pegleg_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_pegleg_technique.id
  )

yellow_british_2011_standing_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Standing falling",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_standing_static_sideways_technique =
  Technique.create!(
    summary: "Standing sideways rolls (into kamae)",
    technique_type_id: yellow_british_2011_standing_ukemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_standing_static_sideways_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_standing_static_sideways_technique.id
  )
yellow_british_2011_standing_travelling_rolls_technique =
  Technique.create!(
    summary: "Standing Forwards Backwards Sideways",
    technique_type_id: yellow_british_2011_standing_ukemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_standing_travelling_rolls_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_standing_travelling_rolls_technique.id
  )

yellow_canadian_2021_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Punches",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_lunge_punch_technique =
  Technique.create!(
    summary: "Lunge punch",
    technique_type_id: yellow_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_lunge_punch_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_lunge_punch_technique.id
  )
yellow_canadian_2021_reverse_punch_technique =
  Technique.create!(
    summary: "Reverse punch",
    technique_type_id: yellow_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_reverse_punch_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_reverse_punch_technique.id
  )
yellow_canadian_2021_hook_punch_technique =
  Technique.create!(
    summary: "Hook punch",
    technique_type_id: yellow_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_hook_punch_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_hook_punch_technique.id
  )
yellow_canadian_2021_hand_strike_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Hand strikes",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_palm_heel_technique =
  Technique.create!(
    summary: "Palm heel",
    technique_type_id: yellow_canadian_2021_hand_strike_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_palm_heel_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_palm_heel_technique.id
  )
yellow_canadian_2021_knife_hand_technique =
  Technique.create!(
    summary: "Knife hand",
    technique_type_id: yellow_canadian_2021_hand_strike_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_knife_hand_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_knife_hand_technique.id
  )
yellow_canadian_2021_back_fist_technique =
  Technique.create!(
    summary: "Back fist",
    technique_type_id: yellow_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_back_fist_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_back_fist_technique.id
  )

yellow_canadian_2021_elbow_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Elbows",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_horizontal_elbow_technique =
  Technique.create!(
    summary: "Elbow (horizontal)",
    technique_type_id: yellow_canadian_2021_elbow_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_horizonal_elbow_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_horizontal_elbow_technique.id
  )

yellow_canadian_2021_kick_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Kicks",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_front_kick_technique =
  Technique.create!(
    summary: "Mae-geri (front kick)",
    technique_type_id: yellow_canadian_2021_kick_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_front_kick_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_front_kick_technique.id
  )

yellow_british_2011_dangerous_parts_head_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Head)",
    sub_category: "Punches",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_temple_backfist_technique =
  Technique.create!(
    summary:
      "1 - Temple - backfist (right hand, right foot forward, stress hip rotation)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_temple_backfist_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_temple_backfist_technique.id
  )
yellow_british_2011_nose_hammerfist_technique =
  Technique.create!(
    summary: "2 - Bridge of nose - hammerfist (right hand, left foot forward)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_nose_hammerfist_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_nose_hammerfist_technique.id
  )
yellow_british_2011_dangerous_parts_head_gouge_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Head)",
    sub_category: "Gouges",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_eye_gouge_technique =
  Technique.create!(
    summary:
      "3 - Eyes - backfist (right hand index and middle fingers, right foot forward, simulated strike which actually goes past uke's shoulders)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_gouge_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_eye_gouge_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_eye_gouge_technique.id
  )
yellow_british_2011_pressure_point_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Head)",
    sub_category: "Pressure points",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_mastoids_submission_technique =
  Technique.create!(
    summary:
      "4 - Mastoids - fingers (both hands index and middle fingers, feet square, target uke's mastoids under their jaw until tap, alternative with thumbs)",
    technique_type_id: yellow_british_2011_pressure_point_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_mastoids_submission_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_mastoids_submission_technique.id
  )
yellow_british_2011_dangerous_parts_head_hand_strike_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Head)",
    sub_category: "Hand strikes",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_philtrum_strike_technique =
  Technique.create!(
    summary:
      "5 - Philtrum (base of the nose) palm heel strike (right hand, left foot forward)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_hand_strike_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_philtrum_strike_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_philtrum_strike_technique.id
  )
yellow_british_2011_jaw_hammerfist_technique =
  Technique.create!(
    summary:
      "6 - Jaw - hammerfist (right hand, left foot forward, stress hip rotation), alternative punch to side (left hand)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_hand_strike_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_jaw_hammerfist_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_jaw_hammerfist_technique.id
  )
yellow_british_2011_carotids_strike_technique =
  Technique.create!(
    summary:
      "7 - Carotid arteries knife hand strikes (both hands, both feet square)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_hand_strike_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_carotids_strike_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_carotids_strike_technique.id
  )
yellow_british_2011_throat_strike_technique =
  Technique.create!(
    summary:
      "8 - Throat- finger strike (3 finger tips together, right hand, left foot forward)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_head_hand_strike_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_throat_strike_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_throat_strike_technique.id
  )

yellow_british_2011_dangerous_parts_body_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Body)",
    sub_category: "Punches",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_floating_ribs_technique =
  Technique.create!(
    summary:
      "1 - Floating ribs - double punch (left foot forward, one-two combo)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_floating_ribs_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_floating_ribs_technique.id
  )
yellow_british_2011_solar_plexus_technique =
  Technique.create!(
    summary:
      "2 - Solar plexus - uppercut (right hand, left foot forward), alternative elbow, uke behind",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_floating_ribs_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_solar_plexus_technique.id
  )
yellow_british_2011_dangerous_parts_body_knee_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Body)",
    sub_category: "Knees",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_knee_groin_technique =
  Technique.create!(
    summary:
      "3 - Groin - right knee (use both hands to grip uke's shoulders), alternative mae geri (front kick)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_knee_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_knee_groin_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_knee_groin_technique.id
  )
yellow_british_2011_dangerous_parts_body_kick_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Body)",
    sub_category: "Kicks",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_kick_thigh_technique =
  Technique.create!(
    summary:
      "4 - Side of thigh - mawashi geri with tori's right shin, alternative knee (move to side, use right knee)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kick_thigh_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kick_thigh_technique.id
  )
yellow_british_2011_kick_knee_technique =
  Technique.create!(
    summary: "5 - Knee - right mae geri from 5, alternative yoko geri",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kick_knee_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kick_knee_technique.id
  )
yellow_british_2011_kick_shin_technique =
  Technique.create!(
    summary: "6 - Shin - right legged rake from 6",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kick_shin_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kick_shin_technique.id
  )
yellow_british_2011_foot_stomp_technique =
  Technique.create!(
    summary:
      "7 - Foot stomp - use right foot to simulate next to uke's right foot (alternative: uke on floor - stomp on foot; note also ankle, shin, hand, arm)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_body_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_foot_stomp_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_foot_stomp_technique.id
  )

yellow_british_2011_dangerous_parts_back_strike_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Back)",
    sub_category: "Hand strikes",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_back_of_skull_technique =
  Technique.create!(
    summary:
      "1 - Across back of skull - knife hand (right hand, right foot forward, stress hip rotation), alternative same strike with uke bent double",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_strike_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_back_of_skull_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_back_of_skull_technique.id
  )
yellow_british_2011_dangerous_parts_back_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Back)",
    sub_category: "Punches",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_top_of_spine_technique =
  Technique.create!(
    summary: "2 - Top of spine - hammerfist (right hand, left foot forward)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_top_of_spine_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_top_of_spine_technique.id
  )
yellow_british_2011_kidneys_punch_technique =
  Technique.create!(
    summary: "3 - Kidneys - double punch (one-two combo, feet square)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_punch_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kidneys_punch_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kidneys_punch_technique.id
  )
yellow_british_2011_dangerous_parts_back_elbow_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Back)",
    sub_category: "Elbows",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_small_of_back_technique =
  Technique.create!(
    summary:
      "4 - Small of back - right elbow (right fist is braced by left hand, right foot forward)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_elbow_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_small_of_back_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_small_of_back_technique.id
  )
yellow_british_2011_coccyx_technique =
  Technique.create!(
    summary:
      "5 - Coccyx - right elbow (right fist is braced by left hand, right foot forward), alternative with right knee and both hands on uke's shoulders",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_elbow_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_coccyx_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_coccyx_technique.id
  )
yellow_british_2011_dangerous_parts_back_kick_atemi_type =
  TechniqueType.create!(
    category: "Atemi (Dangerous Parts, Back)",
    sub_category: "Kicks",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_back_of_knee_technique =
  Technique.create!(
    summary:
      "6 - Back of knee - right yoko geri (right foot forward, kick uke's left knee)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_back_of_knee_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_back_of_knee_technique.id
  )
yellow_british_2011_achilles_technique =
  Technique.create!(
    summary:
      "7 - Achilles heel - right stomp - right yoko geri (right foot forward, kick uke's left achilles)",
    technique_type_id:
      yellow_british_2011_dangerous_parts_back_kick_atemi_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_achilles_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_achilles_technique.id
  )

yellow_british_2011_kicks_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Kicks",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_mae_geri_technique =
  Technique.create!(
    summary: "Mae geri (front kick)",
    technique_type_id: yellow_british_2011_kicks_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_mae_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_mae_geri_technique.id
  )
yellow_british_2011_mae_washi_geri_technique =
  Technique.create!(
    summary: "Mae washi geri (front round kick)",
    technique_type_id: yellow_british_2011_kicks_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_mae_washi_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_mae_washi_geri_technique.id
  )
yellow_british_2011_yoko_geri_technique =
  Technique.create!(
    summary: "Yoko geri (side kick)",
    technique_type_id: yellow_british_2011_kicks_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_yoko_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_yoko_geri_technique.id
  )

yellow_canadian_2021_wrist_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Wrist locks",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_kote_gaeshi_technique =
  Technique.create!(
    summary: "Wrist-lock #1 (Kote-gaeshi, wrist twist)",
    technique_type_id: yellow_canadian_2021_wrist_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_kote_gaeshi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_kote_gaeshi_technique.id
  )
yellow_canadian_2021_ura_kote_technique =
  Technique.create!(
    summary: "Wrist-lock #2 (Ura-kote, Rear wrist)",
    technique_type_id: yellow_canadian_2021_wrist_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_ura_kote_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_ura_kote_technique.id
  )

yellow_canadian_2021_arm_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Arm locks",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_ude_kujiki_technique =
  Technique.create!(
    summary: "Arm-lock #1 (Ude-kujiki, arm break)",
    technique_type_id: yellow_canadian_2021_arm_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_ude_kujiki_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_ude_kujiki_technique.id
  )
yellow_canadian_2021_karada_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #2 (Karada-gatame, body lock)",
    technique_type_id: yellow_canadian_2021_arm_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_karada_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_karada_gatame_technique.id
  )

yellow_canadian_2021_ground_restraint_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Ground restraints",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_yoko_hiza_gatame_restraint_technique =
  Technique.create!(
    summary: "Restraint #1 (Yoko-hiza-gatame, side knee lock)",
    technique_type_id: yellow_canadian_2021_ground_restraint_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_yoko_hiza_gatame_restraint_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_yoko_hiza_gatame_restraint_technique.id
  )
yellow_canadian_2021_yoko_kote_dori_restraint_technique =
  Technique.create!(
    summary: "Restraint #2 (Yoko-kote-dori, side wrist trap) [wrist-lock #5]",
    technique_type_id: yellow_canadian_2021_ground_restraint_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_yoko_hiza_gatame_restraint_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_yoko_kote_dori_restraint_technique.id
  )
yellow_canadian_2021_ura_kote_restraint_technique =
  Technique.create!(
    summary: "Restraint #3 (Ura-kote, rear wrist [wrist-lock #2])",
    technique_type_id: yellow_canadian_2021_ground_restraint_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_ura_kote_restraint_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_ura_kote_restraint_technique.id
  )

yellow_british_2011_wrist_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Wrist locks without put-down",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_kote_gaeshi_technique =
  Technique.create!(
    summary: "Wrist-lock #1 (Kote-gaeshi, wrist twist/turn over)",
    technique_type_id: yellow_british_2011_wrist_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kote_gaeshi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kote_gaeshi_technique.id
  )

yellow_british_2011_ura_kote_technique =
  Technique.create!(
    summary: "Wrist-lock #2 (Ura-kote, Rear wrist)",
    technique_type_id: yellow_british_2011_wrist_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_ura_kote_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_ura_kote_technique.id
  )
yellow_british_2011_kote_gatame_technique =
  Technique.create!(
    summary: "Wrist-lock #3 (Kote-gatame, Wrist lock)",
    technique_type_id: yellow_british_2011_wrist_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kote_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kote_gatame_technique.id
  )

yellow_british_2011_arm_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Arm locks",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_kujiki_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #1 from outside (Kujiki gatame, arm break)",
    technique_type_id: yellow_british_2011_arm_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kujiki_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kujiki_gatame_technique.id
  )
yellow_british_2011_kannuki_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #1 from inside (Kannuki gatame, bolt lock)",
    technique_type_id: yellow_british_2011_arm_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kannuki_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kannuki_gatame_technique.id
  )
yellow_british_2011_karada_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #2 (Karada-gatame, body lock)",
    technique_type_id: yellow_british_2011_arm_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_karada_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_british_2011_karada_gatame_technique.id
  )
yellow_british_2011_katsugi_gatame_technique =
  Technique.create!(
    summary:
      "Arm-lock #2 for a tall person (Katsugi-gatame, shoulder-carry lock)",
    technique_type_id: yellow_british_2011_arm_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_katsugi_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_british_2011_katsugi_gatame_technique.id
  )
yellow_british_2011_jodan_ude_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #3 (Jodan-ude-gatame, upper body arm entanglement)",
    technique_type_id: yellow_british_2011_arm_kansetsu_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_jodan_ude_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_british_2011_jodan_ude_gatame_technique.id
  )

yellow_canadian_2021_ground_control_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground control",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_tate_shiho_gatame_technique =
  Technique.create!(
    summary:
      "Tate-shiho-gatame (Straight-four-corner-hold aka top control aka mount) (and escape from aka counters)",
    technique_type_id: yellow_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_tate_shiho_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_tate_shiho_gatame_technique.id
  )
yellow_canadian_2021_mune_gatame_technique =
  Technique.create!(
    summary:
      "Mune-gatame (Chest hold aka side control) (and escape from aka counters)",
    technique_type_id: yellow_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_mune_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_mune_gatame_technique.id
  )
yellow_canadian_2021_kesa_gatame_technique =
  Technique.create!(
    summary: "Kesa-gatame (Scarf hold) (and counters)",
    technique_type_id: yellow_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_kesa_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_kesa_gatame_technique.id
  )
yellow_canadian_2021_guard_technique =
  Technique.create!(
    summary: "Supine control aka guard (and escapes from)",
    technique_type_id: yellow_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_guard_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_guard_technique.id
  )

yellow_canadian_2021_ground_arm_locks_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground arm locks",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_ude_hishigi_ude_gatame_technique =
  Technique.create!(
    summary: "Ude-hishigi-ude-gatame (Arm crush arm-lock) (and counters)",
    technique_type_id: yellow_canadian_2021_ground_arm_locks_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_ude_hishigi_ude_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_ude_hishigi_ude_gatame_technique.id
  )
yellow_canadian_2021_ude_hishigi_juji_gatame_technique =
  Technique.create!(
    summary: "Ude-hishigi-juji-gatame (Cross crush arm-lock) (and counters)",
    technique_type_id: yellow_canadian_2021_ground_arm_locks_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_ude_hishigi_juji_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_ude_hishigi_juji_gatame_technique.id
  )

yellow_canadian_2021_ground_strangles_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground strangles",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_tsukomi_jime_technique =
  Technique.create!(
    summary: "Tsukomi-jime (Thrust strangle) (and counters)",
    technique_type_id: yellow_canadian_2021_ground_strangles_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_tsukomi_jime_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_tsukomi_jime_technique.id
  )
yellow_canadian_2021_okuri_eri_jime_technique =
  Technique.create!(
    summary: "Okuri-eri-jime (Sliding collar strangle) (and counters)",
    technique_type_id: yellow_canadian_2021_ground_strangles_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_okuri_eri_jime_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_okuri_eri_jime_technique.id
  )

yellow_british_2011_ground_control_osaekomi_waza_type =
  TechniqueType.create!(
    category: "Osaekomi",
    sub_category: "Ground control",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_kesa_gatame_technique =
  Technique.create!(
    summary: "Kesa-gatame (Scarf hold)",
    technique_type_id: yellow_british_2011_ground_control_osaekomi_waza_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_kesa_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_kesa_gatame_technique.id
  )
yellow_british_2011_mune_gatame_technique =
  Technique.create!(
    summary: "Mune-gatame (Chest hold aka side control)",
    technique_type_id: yellow_british_2011_ground_control_osaekomi_waza_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_mune_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_mune_gatame_technique.id
  )

yellow_canadian_2021_throws_nage_type =
  TechniqueType.create!(
    category: "Nage",
    sub_category: "Throws",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_osoto_gari_technique =
  Technique.create!(
    summary: "Osoto-gari (Major outer reap)",
    technique_type_id: yellow_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_osoto_gari_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_osoto_gari_technique.id
  )
yellow_canadian_2021_kosoto_gari_technique =
  Technique.create!(
    summary: "Kosoto-gari (Minor outer reap)",
    technique_type_id: yellow_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_kosoto_gari_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_kosoto_gari_technique.id
  )
yellow_canadian_2021_de_ashi_harai_technique =
  Technique.create!(
    summary: "De-ashi-harai (Advancing foot sweep)",
    technique_type_id: yellow_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_de_ashi_harai_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_de_ashi_harai_technique.id
  )

yellow_canadian_2021_kuzushi_nage_type =
  TechniqueType.create!(
    category: "Nage",
    sub_category: "Kuzushi",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_kuzushi_technique =
  Technique.create!(
    summary: "Demonstrate Kuzushi (Points of unbalance)",
    technique_type_id: yellow_canadian_2021_kuzushi_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_kuzushi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_kuzushi_technique.id
  )

yellow_canadian_2021_randori_nage_type =
  TechniqueType.create!(
    category: "Nage",
    sub_category: "Randori",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_randori_technique =
  Technique.create!(
    summary:
      "Randori (Competitive throwing) utilising Osoto-gari and De-ashi-harai only",
    technique_type_id: yellow_canadian_2021_randori_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_randori_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_randori_technique.id
  )

yellow_canadian_2021_henka_waza_kansetsu_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Locking transitions",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_locking_transition_one_technique =
  Technique.create!(
    summary: "Arm-lock 2 into wrist-lock 1",
    technique_type_id: yellow_canadian_2021_henka_waza_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_locking_transition_one_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_locking_transition_one_technique.id
  )
yellow_canadian_2021_locking_transition_two_technique =
  Technique.create!(
    summary: "Arm-lock 1 into wrist-lock 1",
    technique_type_id: yellow_canadian_2021_henka_waza_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_locking_transition_two_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_locking_transition_two_technique.id
  )

yellow_canadian_2021_henka_waza_ne_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Groundfighting transitions",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_groundfighting_transition_one_technique =
  Technique.create!(
    summary: "Mune-gatame into ude-hishigi-ude-gatame",
    technique_type_id: yellow_canadian_2021_henka_waza_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_groundfighting_transition_one_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id:
      yellow_canadian_2021_groundfighting_transition_one_technique.id
  )
yellow_canadian_2021_groundfighting_transition_two_technique =
  Technique.create!(
    summary: "Tate-shiho-gatame into ude-hishigi-juji-gatame",
    technique_type_id: yellow_canadian_2021_henka_waza_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_groundfighting_transition_two_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id:
      yellow_canadian_2021_groundfighting_transition_two_technique.id
  )

yellow_canadian_2021_henka_waza_nage_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Throwing transitions",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_throwing_transition_technique =
  Technique.create!(
    summary: "Kosoto-gari into Osoto-gari",
    technique_type_id: yellow_canadian_2021_henka_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_throwing_transition_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_throwing_transition_technique.id
  )

yellow_canadian_2021_bunkai_grab_type =
  TechniqueType.create!(
    category: "Bunkai",
    sub_category: "Head grabs",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_strangle_defence_technique =
  Technique.create!(
    summary: "Defence against strangles (front and rear)",
    technique_type_id: yellow_canadian_2021_bunkai_grab_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_strangle_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_strangle_defence_technique.id
  )
yellow_canadian_2021_hair_grab_defence_technique =
  Technique.create!(
    summary: "Defence against hair grabs (front and rear)",
    technique_type_id: yellow_canadian_2021_bunkai_grab_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_hair_grab_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_hair_grab_defence_technique.id
  )
yellow_canadian_2021_grab_punch_defence_technique =
  Technique.create!(
    summary: "Defence against lapel punch & grab",
    technique_type_id: yellow_canadian_2021_bunkai_grab_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_grab_punch_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_grab_punch_defence_technique.id
  )
yellow_canadian_2021_bunkai_weapon_type =
  TechniqueType.create!(
    category: "Bunkai",
    sub_category: "Weapon defences",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_bottle_defence_technique =
  Technique.create!(
    summary: "Defence against bottle",
    technique_type_id: yellow_canadian_2021_bunkai_weapon_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_bottle_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_bottle_defence_technique.id
  )

yellow_canadian_2021_misc_type =
  TechniqueType.create!(
    category: "Misc",
    sub_category: "Eiquette",
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_canada_2021.id
  )
yellow_canadian_2021_etiquette_technique =
  Technique.create!(
    summary:
      "The student should have good style and control and a basic knowledge of terminology and eiquette.",
    technique_type_id: yellow_canadian_2021_misc_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["yellow"].id
  )
yellow_canadian_2021_etiquette_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: yellow_canadian_2021_etiquette_technique.id
  )
# If indeed we create an etiquette video!

yellow_british_2011_defence_grab_type =
  TechniqueType.create!(
    category: "Defence",
    sub_category: "Grabs",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_strangles_technique =
  Technique.create!(
    summary: "Defence against strangles from front and rear",
    technique_type_id: yellow_british_2011_defence_grab_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_strangles_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_strangles_technique.id
  )
yellow_british_2011_head_grab_technique =
  Technique.create!(
    summary: "Defence against hair and ear grabs from front and rear",
    technique_type_id: yellow_british_2011_defence_grab_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_head_grab_videos =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_head_grab_technique.id
  )
yellow_british_2011_single_wrist_grab_technique =
  Technique.create!(
    summary:
      "Defence against single-handed wrst grabs from the front with releases",
    technique_type_id: yellow_british_2011_defence_grab_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_single_wrist_grab_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_single_wrist_grab_technique.id
  )
yellow_british_2011_front_two_wrist_grab_technique =
  Technique.create!(
    summary:
      "Defence against two hands grabbing single wrist from the front with releases",
    technique_type_id: yellow_british_2011_defence_grab_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_front_two_wrist_grab_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_front_two_wrist_grab_technique.id
  )
yellow_british_2011_defence_punch_type =
  TechniqueType.create!(
    category: "Defence",
    sub_category: "Punches",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_punch_throw_technique =
  Technique.create!(
    summary: "Defence against a punch using throws",
    technique_type_id: yellow_british_2011_defence_grab_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_punch_throw_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_punch_throw_technique.id
  )
yellow_british_2011_defence_weapon_type =
  TechniqueType.create!(
    category: "Defence",
    sub_category: "Weapon Defences",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.idc
  )
yellow_british_2011_bottle_technique =
  Technique.create!(
    summary: "Bottle disarms from forearm and backhand attacks",
    technique_type_id: yellow_british_2011_defence_weapon_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_bottle_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_bottle_technique.id
  )
yellow_british_2011_defence_middlework_type =
  TechniqueType.create!(
    category: "Defence",
    sub_category: "Middlework",
    belt_id: UK_2011_BELT_MAP["yellow"].id,
    syllabus_id: syllabus_britain_2011.id
  )
yellow_british_2011_v_technique =
  Technique.create!(
    summary: "Introduction to defence in a 'V'",
    technique_type_id: yellow_british_2011_defence_weapon_type.id,
    belt_id: UK_2011_BELT_MAP["yellow"].id
  )
yellow_british_2011_v_video =
  create_seed_video(
    url: "Dummy URL",
    country: "UK",
    technique_id: yellow_british_2011_v_technique.id
  )
orange_canadian_2021_standing_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Standing falling",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_standing_rolling_technique =
  Technique.create!(
    summary: "Standing forwards and backwards rolls (into kamae)",
    technique_type_id: orange_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_standing_rolling_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_standing_rolling_technique.id
  )
orange_canadian_2021_standing_otb_technique =
  Technique.create!(
    summary: "Over the belt,",
    technique_type_id: orange_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_standing_otb_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_standing_otb_technique.id
  )
orange_canadian_2021_standing_side_drop_technique =
  Technique.create!(
    summary: "side drop",
    technique_type_id: orange_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  ) # aka kick up and drop
orange_canadian_2021_standing_otb_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_standing_side_drop_technique.id
  )
orange_canadian_2021_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Punches",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_hammer_fist_technique =
  Technique.create!(
    summary: "Hammer fist",
    technique_type_id: orange_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_hammer_fist_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_hammer_fist_technique.id
  )
orange_canadian_2021_elbow_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Elbows",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_elbow_technique =
  Technique.create!(
    summary: "Elbow (vertical)",
    technique_type_id: orange_canadian_2021_elbow_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_elbow_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_elbow_atemi_type.id
  )
orange_canadian_2021_knee_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Knees",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_knee_technique =
  Technique.create!(
    summary: "Knee",
    technique_type_id: orange_canadian_2021_knee_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_knee_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_knee_atemi_type.id
  )

orange_british_2011_standing_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Standing falling",
    belt_id: UK_2011_BELT_MAP["orange"].id,
    syllabus_id: syllabus_britain_2011.id
  )
orange_canadian_2021_kick_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Kicks",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_mawashi_geri_technique =
  Technique.create!(
    summary: "Mawashi-geri",
    technique_type_id: orange_canadian_2021_kick_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_mawashi_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_mawashi_geri_technique.id
  )
orange_canadian_2021_wrist_lock_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Wrist locks",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_kote_gatame_technique =
  Technique.create!(
    summary: "Wrist-lock #3 (Kote-gatame)",
    technique_type_id: orange_canadian_2021_wrist_lock_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kote_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kote_gatame_technique.id
  )
orange_canadian_2021_arm_lock_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Arm locks",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_ude_garami_technique =
  Technique.create!(
    summary: "Arm-lock #3 (Ude-garami)",
    technique_type_id: orange_canadian_2021_arm_lock_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_ude_garami_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_ude_garami_technique.id
  )
orange_canadian_2021_gyaku_ude_garami_technique =
  Technique.create!(
    summary: "Arm-lock #4 (Gyaku-ude-garami)",
    technique_type_id: orange_canadian_2021_arm_lock_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_gyaku_ude_garami_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_gyaku_ude_garami_technique.id
  )
orange_canadian_2021_ground_restraint_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Ground restraints",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_ashi_gatame_restraint_technique =
  Technique.create!(
    summary: "Restraint #4 (Ashi-gatame, ???)",
    technique_type_id: orange_canadian_2021_ground_restraint_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_ashi_gatame_restraint_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_ashi_gatame_restraint_technique.id
  )
orange_canadian_2021_gyaku_kote_hineri_restraint_technique =
  Technique.create!(
    summary: "Restraint #5 (Gyaku-kote-hineri, ???)",
    technique_type_id: orange_canadian_2021_ground_restraint_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_gyaku_kote_hineri_restraint_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_gyaku_kote_hineri_restraint_technique.id
  )
orange_canadian_2021_ground_control_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground control",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_kuzure_kesa_gatame_technique =
  Technique.create!(
    summary: "Kuzure-kesa-gatame (Broken scarf hold) (and counters)",
    technique_type_id: orange_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kuzure_kesa_gatame_technique =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kuzure_kesa_gatame_technique.id
  )
orange_canadian_2021_gyaku_kesa_gatame_technique =
  Technique.create!(
    summary: "Gyaku-kesa-gatame (Reverse scarf hold) (and counters)",
    technique_type_id: orange_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_gyaku_kesa_gatame_technique =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_gyaku_kesa_gatame_technique.id
  )
orange_canadian_2021_kata_gatame_technique =
  Technique.create!(
    summary: "Kata-gatame (Shoulder hold) (and counters)",
    technique_type_id: orange_canadian_2021_ground_control_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kata_gatame_technique =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kata_gatame_technique.id
  )
orange_canadian_2021_ground_arm_locks_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground arm locks",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_ude_garami_technique =
  Technique.create!(
    summary: "Ude-garami (Arm entanglement) (and counters)",
    technique_type_id: orange_canadian_2021_ground_arm_locks_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_ude_garami_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_ude_garami_technique.id
  )
orange_canadian_2021_gyaku_ude_garami_technique =
  Technique.create!(
    summary: "Gyaku-ude-garami (Revere arm entanglement) (and counters)",
    technique_type_id: orange_canadian_2021_ground_arm_locks_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_gyaku_ude_garami_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_gyaku_ude_garami_technique.id
  )
orange_canadian_2021_ground_strangles_ne_type =
  TechniqueType.create!(
    category: "Ne",
    sub_category: "Ground strangles",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_hadaka_jime_technique =
  Technique.create!(
    summary: "Hadaka-jime (Rear naked strangle) (and counters)",
    technique_type_id: orange_canadian_2021_ground_strangles_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_hadaka_jime_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_hadaka_jime_technique.id
  )
orange_canadian_2021_ryote_jime_technique =
  Technique.create!(
    summary: "Ryote-jime (??? strangle) (and counters)",
    technique_type_id: orange_canadian_2021_ground_strangles_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_ryote_jime_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_ryote_jime_technique.id
  )
orange_canadian_2021_throws_nage_type =
  TechniqueType.create!(
    category: "Nage",
    sub_category: "Throws",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_koshi_garuma_technique =
  Technique.create!(
    summary: "Koshi-garuma (Hip wheel)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_koshi_garuma_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_koshi_garuma_technique.id
  )
orange_canadian_2021_o_goshi_technique =
  Technique.create!(
    summary: "O-goshi (Major hip)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_o_goshi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_o_goshi_technique.id
  )
orange_canadian_2021_kouchi_gari_technique =
  Technique.create!(
    summary: "Kouchi-gari (Minor inner reap)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kouchi_gari_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kouchi_gari_technique.id
  )
orange_canadian_2021_kosoto_gake_technique =
  Technique.create!(
    summary: "Kosoto-gake (Minor outer prop)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kosoto_gake_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kosoto_gake_technique.id
  )
orange_canadian_2021_osoto_gaeshi_technique =
  Technique.create!(
    summary: "Osoto-gake (Major outer twist)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_osoto_gaeshi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_osoto_gaeshi_technique.id
  )
orange_canadian_2021_ushiro_goshi_technique =
  Technique.create!(
    summary: "Ushiro-goshi (Reverse-hip)",
    technique_type_id: orange_canadian_2021_throws_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_ushiro_goshi_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_ushiro_goshi_technique.id
  )
orange_canadian_2021_randori_nage_type =
  TechniqueType.create!(
    category: "Nage",
    sub_category: "Randori",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_randori_technique =
  Technique.create!(
    summary: "Randori",
    technique_type_id: orange_canadian_2021_randori_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_randori_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_randori_video.id
  )
orange_canadian_2021_henka_waza_ne_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Groundfighting transitions",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_groundfighting_transition_one_technique =
  Technique.create!(
    summary: "Kesa-gatame into Kata-gatame",
    technique_type_id: orange_canadian_2021_henka_waza_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_groundfighting_transition_one_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id:
      orange_canadian_2021_groundfighting_transition_one_technique.id
  )
orange_canadian_2021_groundfighting_transition_two_technique =
  Technique.create!(
    summary: "Mune-gatame into Gyaku-ude-garami",
    technique_type_id: orange_canadian_2021_henka_waza_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_groundfighting_transition_two_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id:
      orange_canadian_2021_groundfighting_transition_two_technique.id
  )
orange_canadian_2021_groundfighting_transition_three_technique =
  Technique.create!(
    summary: "Tate-shiho-gatame into Ude-garami",
    technique_type_id: orange_canadian_2021_henka_waza_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_groundfighting_transition_three_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id:
      orange_canadian_2021_groundfighting_transition_three_technique.id
  )
orange_canadian_2021_henka_waza_nage_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Throwing transitions",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_throwing_transition_technique =
  Technique.create!(
    summary: "De-ashi-harai into Kosoto-gari",
    technique_type_id: orange_canadian_2021_henka_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_throwing_transition_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_transition_technique.id
  )
orange_canadian_2021_henka_waza_nage_type =
  TechniqueType.create!(
    category: "Henka",
    sub_category: "Throwing transitions",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_throwing_transition_technique =
  Technique.create!(
    summary: "De-ashi-harai into Kosoto-gari",
    technique_type_id: orange_canadian_2021_henka_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_throwing_transition_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_transition_technique.id
  )
orange_canadian_2021_kaeshi_waza_nage_type =
  TechniqueType.create!(
    category: "Kaeshi",
    sub_category: "Throwing counters",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_throwing_counter_one_technique =
  Technique.create!(
    summary: "Osoto-gari with Osoto-gaeshi",
    technique_type_id: orange_canadian_2021_kaeshi_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_throwing_counter_one_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_counter_one_technique.id
  )
orange_canadian_2021_throwing_counter_two_technique =
  Technique.create!(
    summary: "Osoto-gari with Kosoto-gari",
    technique_type_id: orange_canadian_2021_kaeshi_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_throwing_counter_two_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_counter_two_technique.id
  )
orange_canadian_2021_throwing_counter_three_technique =
  Technique.create!(
    summary: "Kosoto-gari with O-goshi",
    technique_type_id: orange_canadian_2021_kaeshi_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_throwing_counter_three_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_counter_three_technique.id
  )
orange_canadian_2021_throwing_counter_four_technique =
  Technique.create!(
    summary: "Koshi-guruma with Ushiro-goshi",
    technique_type_id: orange_canadian_2021_kaeshi_waza_nage_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id

orange_canadian_2021_throwing_counter_four_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_throwing_counter_four_technique.id
  )

  orange_canadian_2021_bunkai_grab_type =
  TechniqueType.create!(
    category: "Bunkai",
    sub_category: "Body grabs",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_body_grab_technique =
  Technique.create!(
    summary: "Defence against body grabs (front and rear)",
    technique_type_id: orange_canadian_2021_bunkai_grab_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_body_grab_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_body_grab_technique.id
  )
    orange_canadian_2021_bunkai_kick_type =
  TechniqueType.create!(
    category: "Bunkai",
    sub_category: "Kick defences",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_kick_defence_technique =
  Technique.create!(
    summary: "Defence against kick",
    technique_type_id: orange_canadian_2021_bunkai_weapon_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id
  )
orange_canadian_2021_kick_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_kick_defence_technique.id
  )
  orange_canadian_2021_bunkai_weapon_type =
  TechniqueType.create!(
    category: "Bunkai",
    sub_category: "Weapon defences",
    belt_id: CANADIAN_2021_BELT_MAP["orange"].id,
    syllabus_id: syllabus_canada_2021.id
  )
orange_canadian_2021_cosh_defence_technique =
  Technique.create!(
    summary: "Defence against cosh",
    technique_type_id: orange_canadian_2021_bunkai_weapon_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["oraoge"].id
  )
orange_canadian_2021_cosh_defence_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_canadian_2021_cosh_defence_technique.id
  )

orange_british_2011_pegleg_technique =
  Technique.create!(
    summary: "Peg-leg break-fall",
    technique_type_id: orange_british_2011_standing_ukemi_type.id,
    belt_id: UK_2011_BELT_MAP["orange"].id
  )
orange_british_2011_pegleg_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: orange_british_2011_pegleg_technique.id
  )

green_canadian_2021_standing_ukemi_type =
  TechniqueType.create!(
    category: "Ukemi",
    sub_category: "Standing falling",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_2021_off_back_technique =
  Technique.create!(
    summary: "Off the back,",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_off_back_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_off_back_technique.id
  )
  green_canadian_2021_diving_technique =
  Technique.create!(
    summary: "diving over one person",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_diving_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_diving_technique.id
  )
    green_canadian_2021_judo_roll_technique =
  Technique.create!(
    summary: "Judo rolls,",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_judo_roll_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_judo_roll_technique.id
  )
     green_canadian_2021_aikido_roll_technique =
  Technique.create!(
    summary: "aikido rolls,",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_aikido_roll_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_aikido_roll_technique.id
  )
       green_canadian_2021_wrong_footed_technique =
  Technique.create!(
    summary: "wrong footed rolls/falls,",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_wrong_footed_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_wrong_footed_technique.id
  )
       green_canadian_2021_alternative_roll_technique =
  Technique.create!(
    summary: "rolls into alternative stances",
    technique_type_id: green_canadian_2021_standing_ukemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_alternative_roll_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_alternative_roll_technique.id
  )

  green_canadian_2021_punch_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Upper-cut",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_2021_uppercut_technique =
  Technique.create!(
    summary: "Upper-cut",
    technique_type_id: green_canadian_2021_punch_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_uppercut_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_uppercut_technique.id
  )
  green_canadian_2021_kick_atemi_type =
  TechniqueType.create!(
    category: "Atemi",
    sub_category: "Kick",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_2021_yoko_geri_technique =
  Technique.create!(
    summary: "Yoko-geri (side kick)",
    technique_type_id: green_canadian_2021_kick_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_yoko_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_yoko_geri_technique.id
  )
green_canadian_2021_ushiro_geri_technique =
  Technique.create!(
    summary: "Ushiro-geri (rear kick)",
    technique_type_id: green_canadian_2021_kick_atemi_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_ushiro_geri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_ushiro_geri_technique.id
  )
  green_canadian_2021_wrist_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Wrist locks",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_2021_kote_hineri_technique =
  Technique.create!(
    summary: "Wrist-lock #4 (Kote-hineri, wrist twist???)",
    technique_type_id: green_canadian_2021_wrist_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_kote_hineri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_kote_hineri_technique.id
  )
green_canadian_2021_kote_dori_technique =
  Technique.create!(
    summary: "Wrist-lock #5 (Kote-dori, wrist crush???)",
    technique_type_id: green_canadian_2021_wrist_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_kote_dori_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_kote_dori_technique.id
  )  
  green_canadian_2021_gyaku_kote_hineri_technique =
  Technique.create!(
    summary: "Wrist-lock #6 (Gyaku-kote-hineri, reverse wrist twist???)",
    technique_type_id: green_canadian_2021_wrist_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_gyaku_kote_hineri_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_gyaku_kote_hineri_technique.id
  )
    green_canadian_2021_arm_kansetsu_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Arm locks",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
green_canadian_2021_waki_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #5 (Waki-gatame, ???)",
    technique_type_id: green_canadian_2021_arm_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_waki_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_waki_gatame_technique.id
  )  
  green_canadian_2021_ude_gatame_technique =
  Technique.create!(
    summary: "Arm-lock #6 (Ude-gatame, ???)",
    technique_type_id: green_canadian_2021_arm_kansetsu_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_ude_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_ude_gatame_technique.id
  )

    green_canadian_2021_groundhold_ne_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Groundholds",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
    green_canadian_2021_kami_shiho_gatame_technique =
  Technique.create!(
    summary: "Kami-shiho-gatame (???)",
    technique_type_id: green_canadian_2021_groundhold_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_kami_shiho_gatame_technique =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_kami_shiho_gatame_technique.id
  )
 green_canadian_2021_yoko_shiho_gatame_technique =
  Technique.create!(
    summary: "Yoko-shiho-gatame (side four corner hold)",
    technique_type_id: green_canadian_2021_groundhold_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_yoko_shiho_gatame_video =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_yoko_shiho_gatame_technique.id
  )


      green_canadian_2021_groundhold_ne_type =
  TechniqueType.create!(
    category: "Kansetsu",
    sub_category: "Groundholds",
    belt_id: CANADIAN_2021_BELT_MAP["green"].id,
    syllabus_id: syllabus_canada_2021.id
  )
    green_canadian_2021_kami_shiho_gatame_technique =
  Technique.create!(
    summary: "Kami-shiho-gatame (???)",
    technique_type_id: green_canadian_2021_groundhold_ne_type.id,
    belt_id: CANADIAN_2021_BELT_MAP["green"].id
  )
green_canadian_2021_kami_shiho_gatame_technique =
  create_seed_video(
    url: "Dummy URL",
    country: "Canada",
    technique_id: green_canadian_2021_kami_shiho_gatame_technique.id
  )


users = User.all
belts = Belt.all

puts "Associating all users with the Canadian Syllabus..."
users.each do |user|
  UserSyllabus.find_or_create_by!(user: user, syllabus: syllabus_canada_2021)
end
puts "-> Done. All users now own the Canadian Syllabus."

puts "Associating all users with the UK Syllabus..."
users.each do |user|
  UserSyllabus.find_or_create_by!(user: user, syllabus: syllabus_britain_2011)
end
puts "-> Done. All users now own the UK Syllabus."

total_users_count = User.count

puts Cowsay.say("Generated #{total_users_count} users", :sheep)
puts Cowsay.say("Generated #{Belt.count} belt colours", :beavis)
puts Cowsay.say("Generated #{Syllabus.count} syllabi", :sheep)
puts Cowsay.say("Generated #{BeltGrade.count} belt grades for users", :cow)
puts Cowsay.say(
       "Generated #{Qualification.count} instructor qualification types",
       :tux
     )
puts Cowsay.say(
       "Generated #{InstructorQualification.count} instructor qualifications for users",
       :frogs
     )
puts Cowsay.say("Generated #{TechniqueType.count} technique types", :daemon)
puts Cowsay.say("Generated #{Video.count} videos", :dragon)

puts "Login with #{admin_user.email} and password of '#{PASSWORD}'"
