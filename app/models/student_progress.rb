class StudentProgress < ApplicationRecord
  self.table_name = "student_progress"

  belongs_to :lti_launch

  validates :canvas_course_id, presence: true
  validates :canvas_user_id,   presence: true

  def progress_percentage
    return 0 if assignments_total.to_i.zero?
    ((assignments_completed.to_f / assignments_total) * 100).round
  end
end
