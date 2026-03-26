FactoryBot.define do
  factory :course_content do
    canvas_course_id { "course_#{SecureRandom.hex(4)}" }
    title            { "Lesson #{SecureRandom.hex(3)}" }
    published_version { nil }
  end
end
