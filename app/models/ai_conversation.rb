class AiConversation < ApplicationRecord
  belongs_to :lti_launch

  validates :canvas_user_id,   presence: true
  validates :canvas_course_id, presence: true

  def append_message(role, content)
    messages << { "role" => role, "content" => content, "timestamp" => Time.current.iso8601 }
    save!
  end

  def api_messages
    messages.map { |m| { "role" => m["role"], "content" => m["content"] } }
  end
end
