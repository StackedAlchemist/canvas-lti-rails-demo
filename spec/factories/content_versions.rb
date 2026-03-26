FactoryBot.define do
  factory :content_version do
    association :course_content
    body           { "Sample content body." }
    author_id      { "user_#{SecureRandom.hex(4)}" }
    author_name    { "Test Author" }
    version_number { 1 }
    status         { "draft" }
    change_summary { nil }
  end
end
