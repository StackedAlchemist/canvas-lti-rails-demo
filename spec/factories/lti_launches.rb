FactoryBot.define do
  factory :lti_launch do
    user_id        { "user_#{SecureRandom.hex(4)}" }
    canvas_user_id { user_id }
    course_id      { "course_#{SecureRandom.hex(4)}" }
    roles          { "Learner" }
    lineitem_url   { "https://canvas.example.com/api/lti/courses/1/line_items/1" }
    canvas_domain  { "canvas.example.com" }
    raw_jwt_claims { {} }
  end
end
