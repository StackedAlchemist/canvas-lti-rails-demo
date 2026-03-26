class CreateGradeSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_table :grade_submissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :lti_launch, type: :uuid, foreign_key: true, null: false
      t.string  :canvas_user_id,     null: false
      t.decimal :score,              precision: 8, scale: 2
      t.decimal :max_score,          precision: 8, scale: 2, default: 100.0
      t.string  :activity_progress,  default: "Completed"
      t.string  :grading_progress,   default: "FullyGraded"
      t.string  :status,             null: false, default: "pending"
      t.jsonb   :canvas_response,    default: {}
      t.string  :error_message
      t.integer :attempt_count,      default: 0, null: false
      t.timestamp :submitted_at

      t.timestamps
    end

    add_index :grade_submissions, [ :canvas_user_id, :lti_launch_id ]
    add_index :grade_submissions, :status
  end
end
