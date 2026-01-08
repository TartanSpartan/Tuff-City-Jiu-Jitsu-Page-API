# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_28_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "belt_grades", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "belt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "obtained_at", default: -> { "CURRENT_DATE" }, null: false
    t.integer "effective_kyu_grade", null: false
    t.index ["belt_id"], name: "index_belt_grades_on_belt_id"
    t.index ["user_id"], name: "index_belt_grades_on_user_id"
  end

  create_table "belts", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "syllabus_id"
    t.integer "kyu_number"
    t.index ["syllabus_id"], name: "index_belts_on_syllabus_id"
  end

  create_table "differences", force: :cascade do |t|
    t.bigint "technique_id", null: false
    t.bigint "compared_to_technique_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compared_to_technique_id"], name: "index_differences_on_compared_to_technique_id"
    t.index ["technique_id"], name: "index_differences_on_technique_id"
  end

  create_table "instructor_qualifications", force: :cascade do |t|
    t.datetime "achieved_at"
    t.bigint "user_id"
    t.bigint "belt_id"
    t.bigint "belt_grade_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "qualification_id", null: false
    t.integer "effective_qualification_id", null: false
    t.index ["belt_grade_id"], name: "index_instructor_qualifications_on_belt_grade_id"
    t.index ["belt_id"], name: "index_instructor_qualifications_on_belt_id"
    t.index ["effective_qualification_id"], name: "index_instructor_qualifications_on_effective_qualification_id"
    t.index ["qualification_id"], name: "index_instructor_qualifications_on_qualification_id"
    t.index ["user_id"], name: "index_instructor_qualifications_on_user_id"
  end

  create_table "qualifications", force: :cascade do |t|
    t.string "level"
    t.bigint "belt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["belt_id"], name: "index_qualifications_on_belt_id"
  end

  create_table "syllabi", force: :cascade do |t|
    t.string "country"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.boolean "is_primary_admin_syllabus", default: false
    t.boolean "is_secondary_admin_syllabus", default: false
    t.index ["user_id"], name: "index_syllabi_on_user_id"
  end

  create_table "technique_types", force: :cascade do |t|
    t.string "category"
    t.string "sub_category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "syllabus_id", null: false
    t.bigint "belt_id", null: false
    t.index ["belt_id"], name: "index_technique_types_on_belt_id"
    t.index ["syllabus_id", "belt_id", "category", "sub_category"], name: "index_technique_types_on_syllabus_belt_category_subcat_not_null", unique: true, where: "(sub_category IS NOT NULL)"
    t.index ["syllabus_id"], name: "index_technique_types_on_syllabus_id"
  end

  create_table "techniques", force: :cascade do |t|
    t.string "summary"
    t.bigint "technique_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "belt_id", null: false
    t.string "default_attack"
    t.index ["belt_id"], name: "index_techniques_on_belt_id"
    t.index ["technique_type_id"], name: "index_techniques_on_technique_type_id"
  end

  create_table "user_syllabi", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "syllabus_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["syllabus_id"], name: "index_user_syllabi_on_syllabus_id"
    t.index ["user_id", "syllabus_id"], name: "index_user_syllabi_on_user_id_and_syllabus_id", unique: true
    t.index ["user_id"], name: "index_user_syllabi_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "google_id"
    t.string "email"
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.boolean "dues_paid"
    t.boolean "owns_gi", default: false
    t.boolean "has_first_aid_qualification"
    t.datetime "first_aid_achievement_date"
    t.datetime "first_aid_expiry_date"
    t.string "google_token"
    t.string "google_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "google_expires_at"
    t.boolean "is_admin", default: false
    t.string "preferred_difference_editor_mode"
    t.datetime "last_sign_in_at", comment: "Timestamp of the user's last successful sign-in"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.string "url", null: false
    t.string "country", null: false
    t.integer "year", null: false
    t.bigint "technique_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["technique_id"], name: "index_videos_on_technique_id"
  end

  create_table "waivers", force: :cascade do |t|
    t.string "participant_name"
    t.string "initials"
    t.string "participant_email_address"
    t.string "participant_address"
    t.text "participant_signature"
    t.string "organization_witness_name"
    t.text "organization_witness_signature"
    t.date "participant_date_of_birth"
    t.string "participant_phone"
    t.string "emergency_contact_name"
    t.string "emergency_contact_number"
    t.string "relationship"
    t.date "signed_on"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((participant_email_address)::text)", name: "index_waivers_on_lower_participant_email_address", unique: true
    t.index ["participant_email_address"], name: "index_waivers_on_participant_email_address"
    t.index ["user_id"], name: "index_waivers_on_user_id"
    t.index ["user_id"], name: "index_waivers_on_user_id_unique_not_null", unique: true, where: "(user_id IS NOT NULL)"
  end

  add_foreign_key "belt_grades", "belts"
  add_foreign_key "belt_grades", "users"
  add_foreign_key "belts", "syllabi"
  add_foreign_key "differences", "techniques"
  add_foreign_key "differences", "techniques", column: "compared_to_technique_id"
  add_foreign_key "instructor_qualifications", "belt_grades"
  add_foreign_key "instructor_qualifications", "belts"
  add_foreign_key "instructor_qualifications", "qualifications", column: "effective_qualification_id"
  add_foreign_key "instructor_qualifications", "users"
  add_foreign_key "qualifications", "belts"
  add_foreign_key "syllabi", "users"
  add_foreign_key "technique_types", "belts"
  add_foreign_key "technique_types", "syllabi"
  add_foreign_key "techniques", "belts"
  add_foreign_key "techniques", "technique_types"
  add_foreign_key "user_syllabi", "syllabi"
  add_foreign_key "user_syllabi", "users"
  add_foreign_key "videos", "techniques"
  add_foreign_key "waivers", "users"
end
