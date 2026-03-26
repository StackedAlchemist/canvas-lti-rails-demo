FactoryBot.define do
  factory :grade_submission do
    association :lti_launch
    canvas_user_id    { "student_#{SecureRandom.hex(4)}" }
    score             { 85.0 }
    max_score         { 100.0 }
    activity_progress { "Completed" }
    grading_progress  { "FullyGraded" }
    status            { "pending" }
  end
end
