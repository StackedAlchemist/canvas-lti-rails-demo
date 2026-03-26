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

ActiveRecord::Schema[7.2].define(version: 2026_03_26_024440) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ai_conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lti_launch_id", null: false
    t.string "canvas_user_id", null: false
    t.string "canvas_course_id", null: false
    t.jsonb "messages", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canvas_user_id", "canvas_course_id"], name: "index_ai_conversations_on_canvas_user_id_and_canvas_course_id"
    t.index ["lti_launch_id"], name: "index_ai_conversations_on_lti_launch_id"
  end

  create_table "content_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "course_content_id", null: false
    t.text "body", null: false
    t.string "author_id", null: false
    t.string "author_name"
    t.integer "version_number", default: 1, null: false
    t.string "status", default: "draft", null: false
    t.string "change_summary"
    t.datetime "created_at", null: false
    t.index ["course_content_id", "version_number"], name: "index_content_versions_on_course_content_id_and_version_number", unique: true
    t.index ["course_content_id"], name: "index_content_versions_on_course_content_id"
    t.index ["status"], name: "index_content_versions_on_status"
  end

  create_table "course_contents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "canvas_course_id", null: false
    t.string "title", null: false
    t.uuid "published_version_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canvas_course_id"], name: "index_course_contents_on_canvas_course_id"
  end

  create_table "grade_submissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lti_launch_id", null: false
    t.string "canvas_user_id", null: false
    t.decimal "score", precision: 8, scale: 2
    t.decimal "max_score", precision: 8, scale: 2, default: "100.0"
    t.string "activity_progress", default: "Completed"
    t.string "grading_progress", default: "FullyGraded"
    t.string "status", default: "pending", null: false
    t.jsonb "canvas_response", default: {}
    t.string "error_message"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "submitted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canvas_user_id", "lti_launch_id"], name: "index_grade_submissions_on_canvas_user_id_and_lti_launch_id"
    t.index ["lti_launch_id"], name: "index_grade_submissions_on_lti_launch_id"
    t.index ["status"], name: "index_grade_submissions_on_status"
  end

  create_table "lti_launches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "canvas_user_id"
    t.string "course_id", null: false
    t.string "roles"
    t.string "lineitem_url"
    t.string "names_roles_url"
    t.string "canvas_domain"
    t.jsonb "raw_jwt_claims", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_lti_launches_on_course_id"
    t.index ["user_id"], name: "index_lti_launches_on_user_id"
  end

  create_table "student_progress", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lti_launch_id", null: false
    t.string "canvas_course_id", null: false
    t.string "canvas_user_id", null: false
    t.integer "assignments_total", default: 0
    t.integer "assignments_completed", default: 0
    t.decimal "grade_to_date", precision: 5, scale: 2, default: "0.0"
    t.datetime "last_activity_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canvas_user_id", "canvas_course_id"], name: "index_student_progress_on_canvas_user_id_and_canvas_course_id", unique: true
    t.index ["lti_launch_id"], name: "index_student_progress_on_lti_launch_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "ai_conversations", "lti_launches"
  add_foreign_key "content_versions", "course_contents"
  add_foreign_key "course_contents", "content_versions", column: "published_version_id", name: "fk_course_contents_published_version"
  add_foreign_key "grade_submissions", "lti_launches"
  add_foreign_key "student_progress", "lti_launches"
end
