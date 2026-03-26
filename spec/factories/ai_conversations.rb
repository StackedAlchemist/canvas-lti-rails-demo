FactoryBot.define do
  factory :ai_conversation do
    association :lti_launch
    canvas_user_id   { "student_#{SecureRandom.hex(4)}" }
    canvas_course_id { "course_#{SecureRandom.hex(4)}" }
    messages         { [] }
  end
end
