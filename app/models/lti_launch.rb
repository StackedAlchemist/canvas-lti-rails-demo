class LtiLaunch < ApplicationRecord
  validates :user_id, presence: true
  validates :course_id, presence: true

  def instructor?
    roles.to_s.include?("Instructor") || roles.to_s.include?("TeachingAssistant")
  end

  def student?
    roles.to_s.include?("Learner") || roles.to_s.include?("Student")
  end
end
