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

ActiveRecord::Schema[8.0].define(version: 2025_08_15_210000) do
  create_table "rails_onboarding_analytics_events", force: :cascade do |t|
    t.string "user_type"
    t.integer "user_id"
    t.string "event_type", null: false
    t.text "properties"
    t.string "session_id"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_rails_onboarding_analytics_events_on_event_type"
    t.index ["occurred_at"], name: "index_rails_onboarding_analytics_events_on_occurred_at"
    t.index ["session_id"], name: "index_rails_onboarding_analytics_events_on_session_id"
    t.index ["user_type", "user_id", "event_type"], name: "idx_on_user_type_user_id_event_type_4f884bc6aa"
    t.index ["user_type", "user_id"], name: "index_rails_onboarding_analytics_events_on_user"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.boolean "onboarding_completed"
    t.datetime "onboarding_completed_at"
    t.string "onboarding_current_step"
    t.boolean "onboarding_skipped"
    t.text "feature_tooltips_shown"
    t.text "milestones_achieved"
    t.integer "milestone_points"
    t.datetime "last_milestone_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
