class AiAssistantService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL          = "claude-sonnet-4-6"
  MAX_TOKENS     = 1000

  class ApiError < StandardError; end

  def initialize(conversation, user_message, lti_launch)
    @conversation  = conversation
    @user_message  = user_message
    @lti_launch    = lti_launch
  end

  def call
    @conversation.append_message("user", @user_message)

    response_text = call_claude_api

    @conversation.append_message("assistant", response_text)
    response_text
  rescue ApiError
    @conversation.messages.pop  # remove the user message we just added if API fails
    @conversation.save!
    raise
  end

  private

  def call_claude_api
    response = HTTParty.post(
      CLAUDE_API_URL,
      headers: {
        "x-api-key"         => ENV.fetch("ANTHROPIC_API_KEY"),
        "anthropic-version" => "2023-06-01",
        "content-type"      => "application/json"
      },
      body: {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        system:     build_system_prompt,
        messages:   @conversation.api_messages
      }.to_json,
      timeout: 30
    )

    raise ApiError, "Claude API error: HTTP #{response.code} — #{response.body}" unless response.success?

    response.parsed_response.dig("content", 0, "text").presence ||
      raise(ApiError, "Empty response from Claude API")
  rescue HTTParty::Error => e
    raise ApiError, "Claude API request failed: #{e.message}"
  end

  def build_system_prompt
    student_name   = @lti_launch.raw_jwt_claims.dig(
                       "https://purl.imsglobal.org/spec/lti/claim/lis", "person_name_full"
                     ) || "the student"
    course_title   = @lti_launch.raw_jwt_claims.dig(
                       "https://purl.imsglobal.org/spec/lti/claim/context", "title"
                     ) || "the course"
    published_body = CourseContent
                       .where(canvas_course_id: @lti_launch.course_id)
                       .includes(:published_version)
                       .filter_map { |c| c.published_version&.body }
                       .join("\n\n---\n\n")

    prompt = <<~PROMPT
      You are a helpful study assistant for #{student_name} in the course "#{course_title}".
      Your role is to help the student understand course material, answer questions, and support their learning.
      Be encouraging, clear, and concise. Never give direct answers to assessments — guide the student to think through problems themselves.
    PROMPT

    if published_body.present?
      prompt += "\n\nHere is the published course content you should draw from when answering questions:\n\n#{published_body}"
    end

    prompt
  end
end
