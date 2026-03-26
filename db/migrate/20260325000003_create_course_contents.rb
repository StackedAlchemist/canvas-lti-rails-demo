class CreateCourseContents < ActiveRecord::Migration[7.2]
  def change
    create_table :course_contents, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :canvas_course_id, null: false
      t.string :title,            null: false
      t.uuid   :published_version_id

      t.timestamps
    end

    add_index :course_contents, :canvas_course_id
  end
end
