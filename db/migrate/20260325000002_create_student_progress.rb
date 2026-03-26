class CreateStudentProgress < ActiveRecord::Migration[7.2]
  def change
    create_table :student_progress, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :lti_launch, type: :uuid, foreign_key: true, null: false
      t.string  :canvas_course_id, null: false
      t.string  :canvas_user_id,   null: false
      t.integer :assignments_total,     default: 0
      t.integer :assignments_completed, default: 0
      t.decimal :grade_to_date,         precision: 5, scale: 2, default: 0.0
      t.timestamp :last_activity_at

      t.timestamps
    end

    add_index :student_progress, [ :canvas_user_id, :canvas_course_id ], unique: true
  end
end
