class GradeSubmission < ApplicationRecord
  belongs_to :lti_launch

  enum :status, { pending: "pending", submitted: "submitted", failed: "failed" }, prefix: false

  validates :canvas_user_id, presence: true
  validates :score,          presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_score,      presence: true, numericality: { greater_than: 0 }
  validates :status,         inclusion: { in: %w[pending submitted failed] }

  def score_percentage
    return 0 if max_score.to_f.zero?
    ((score.to_f / max_score.to_f) * 100).round(2)
  end
end
