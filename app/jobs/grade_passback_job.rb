class GradePassbackJob
  include Sidekiq::Job

  sidekiq_options queue: "grades", retry: 3

  sidekiq_retries_exhausted do |msg, _ex|
    submission_id = msg["args"].first
    GradeSubmission.find_by(id: submission_id)&.update!(
      status:        "failed",
      error_message: "Max retries exhausted: #{msg['error_message']}"
    )
  end

  def perform(submission_id)
    submission = GradeSubmission.find(submission_id)

    # Skip if already submitted successfully
    return if submission.submitted?

    GradePassbackService.new(submission).call
  rescue GradePassbackService::PassbackError => e
    Rails.logger.error "GradePassbackJob failed for #{submission_id}: #{e.message}"
    raise  # re-raise so Sidekiq retries with exponential backoff
  end
end
