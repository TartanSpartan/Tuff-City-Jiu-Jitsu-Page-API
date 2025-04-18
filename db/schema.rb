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

ActiveRecord::Schema[8.0].define(version: 2025_04_16_224740) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "belt_grades", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "belt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["belt_id"], name: "index_belt_grades_on_belt_id"
    t.index ["user_id"], name: "index_belt_grades_on_user_id"
  end

  create_table "belts", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "google_id"
    t.string "email"
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.boolean "dues_paid"
    t.boolean "owns_gi"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "belt_grades", "belts"
  add_foreign_key "belt_grades", "users"
end
