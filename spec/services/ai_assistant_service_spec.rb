require "rails_helper"

RSpec.describe AiAssistantService do
  let(:lti_launch) do
    create(:lti_launch,
      canvas_user_id: "student_001",
      course_id:      "course_abc",
      raw_jwt_claims: {
        "https://purl.imsglobal.org/spec/lti/claim/context" => {
          "id"    => "course_abc",
          "title" => "Intro to Rails"
        },
        "https://purl.imsglobal.org/spec/lti/claim/lis" => {
          "person_name_full" => "Alice Student"
        }
      }
    )
  end

  let(:conversation) do
    create(:ai_conversation,
      lti_launch:      lti_launch,
      canvas_user_id:  lti_launch.canvas_user_id,
      canvas_course_id: lti_launch.course_id
    )
  end

  let(:service) { described_class.new(conversation, "What is a variable?", lti_launch) }

  let(:claude_success_response) do
    {
      "id"      => "msg_abc",
      "type"    => "message",
      "content" => [ { "type" => "text", "text" => "A variable is a named container for a value." } ],
      "model"   => "claude-sonnet-4-6",
      "usage"   => { "input_tokens" => 50, "output_tokens" => 20 }
    }.to_json
  end

  describe "#call" do
    context "when Claude returns a successful response" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status:  200,
            body:    claude_success_response,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "appends the user message to the conversation" do
        service.call
        expect(conversation.messages.any? { |m| m["role"] == "user" }).to be true
      end

      it "appends the assistant response to the conversation" do
        service.call
        expect(conversation.messages.any? { |m| m["role"] == "assistant" }).to be true
      end

      it "returns the assistant response text" do
        result = service.call
        expect(result).to eq("A variable is a named container for a value.")
      end

      it "persists both messages to the database" do
        service.call
        expect(conversation.reload.messages.length).to eq(2)
      end

      it "sends the course title in the system prompt" do
        service.call
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| JSON.parse(req.body)["system"].include?("Intro to Rails") }
      end

      it "sends the student name in the system prompt" do
        service.call
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| JSON.parse(req.body)["system"].include?("Alice Student") }
      end
    end

    context "when the Claude API returns an error" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 529, body: "Overloaded")
      end

      it "raises ApiError" do
        expect { service.call }.to raise_error(AiAssistantService::ApiError, /Claude API error/)
      end

      it "does not persist the user message on failure" do
        service.call rescue nil
        expect(conversation.reload.messages).to be_empty
      end
    end

    context "when the network times out" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_raise(HTTParty::Error.new("execution expired"))
      end

      it "raises ApiError" do
        expect { service.call }.to raise_error(AiAssistantService::ApiError, /request failed/)
      end
    end

    context "when course content is published" do
      let!(:content) do
        c = create(:course_content, canvas_course_id: "course_abc", title: "Lesson 1")
        v = create(:content_version, course_content: c, body: "Variables store data.", version_number: 1, status: "published")
        c.update!(published_version: v)
        c
      end

      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: claude_success_response,
                     headers: { "Content-Type" => "application/json" })
      end

      it "includes published content body in the system prompt" do
        service.call
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| JSON.parse(req.body)["system"].include?("Variables store data.") }
      end
    end
  end
end
