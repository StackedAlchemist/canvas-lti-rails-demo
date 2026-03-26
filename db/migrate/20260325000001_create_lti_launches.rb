class CreateLtiLaunches < ActiveRecord::Migration[7.2]
  def change
    create_table :lti_launches, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :user_id, null: false
      t.string :canvas_user_id
      t.string :course_id, null: false
      t.string :roles
      t.string :lineitem_url
      t.string :names_roles_url
      t.string :canvas_domain
      t.jsonb :raw_jwt_claims, default: {}

      t.timestamps
    end

    add_index :lti_launches, :user_id
    add_index :lti_launches, :course_id
  end
end
