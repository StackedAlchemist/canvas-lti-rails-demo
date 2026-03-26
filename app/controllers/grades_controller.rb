class GradesController < ApplicationController
  before_action :require_lti_launch

  # POST /grades/submit
  def submit
    submission = GradeSubmission.create!(
      lti_launch:        @lti_launch,
      canvas_user_id:    @lti_launch.canvas_user_id,
      score:             grade_params[:score].to_f,
      max_score:         grade_params[:max_score]&.to_f || 100.0,
      activity_progress: "Completed",
      grading_progress:  "FullyGraded",
      status:            "pending"
    )

    Rails.logger.info "[GradePassback] Queued submission #{submission.id} for user #{@lti_launch.canvas_user_id} in course #{@lti_launch.course_id}"

    GradePassbackJob.perform_async(submission.id)

    render json: {
      status:        "queued",
      submission_id: submission.id,
      message:       "Grade submission queued successfully."
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def grade_params
    params.require(:grade).permit(:score, :max_score)
  end
end
