class CreateContentVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :content_versions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :course_content, type: :uuid, foreign_key: true, null: false
      t.text    :body,           null: false
      t.string  :author_id,      null: false
      t.string  :author_name
      t.integer :version_number, null: false, default: 1
      t.string  :status,         null: false, default: "draft"
      t.string  :change_summary

      t.datetime :created_at, null: false
    end

    add_index :content_versions, [ :course_content_id, :version_number ], unique: true
    add_index :content_versions, :status

    add_foreign_key :course_contents, :content_versions,
                    column: :published_version_id, name: "fk_course_contents_published_version"
  end
end
