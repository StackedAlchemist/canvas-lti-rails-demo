class CreateAiConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_conversations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :lti_launch, type: :uuid, foreign_key: true, null: false
      t.string :canvas_user_id,  null: false
      t.string :canvas_course_id, null: false
      t.jsonb  :messages, default: [], null: false

      t.timestamps
    end

    add_index :ai_conversations, [ :canvas_user_id, :canvas_course_id ]
  end
end
