class DashboardController < ApplicationController
  before_action :require_lti_launch
  before_action :set_role

  def show
    @progress = StudentProgress.find_or_create_by!(
      canvas_user_id:   @lti_launch.canvas_user_id,
      canvas_course_id: @lti_launch.course_id
    ) do |p|
      p.lti_launch            = @lti_launch
      p.assignments_total     = 0
      p.assignments_completed = 0
      p.grade_to_date         = 0.0
    end

    @course_name = @lti_launch.raw_jwt_claims
                              .dig("https://purl.imsglobal.org/spec/lti/claim/context", "title") ||
                  "Your Course"
  end

  private

  def set_role
    @is_instructor = @lti_launch.instructor?
    @is_student    = @lti_launch.student?
  end
end
