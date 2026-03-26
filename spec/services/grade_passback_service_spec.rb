require "rails_helper"

RSpec.describe GradePassbackService do
  # Generate a real RSA key for the test run so JWT signing works without .env
  let(:test_rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  before { allow(LtiConfig).to receive(:private_key).and_return(test_rsa_key) }

  let(:lti_launch) do
    create(:lti_launch,
      canvas_user_id: "student_001",
      course_id:      "course_abc",
      lineitem_url:   "https://canvas.example.com/api/lti/courses/1/line_items/1",
      raw_jwt_claims: {
        "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => {
          "lineitem" => "https://canvas.example.com/api/lti/courses/1/line_items/1",
          "scope"    => ["https://purl.imsglobal.org/spec/lti-ags/scope/score"]
        }
      }
    )
  end

  let(:submission) { create(:grade_submission, lti_launch: lti_launch, score: 90.0, max_score: 100.0) }
  let(:service)    { described_class.new(submission) }

  describe "#call" do
    context "when Canvas returns success" do
      before do
        # Stub token request
        stub_request(:post, /canvas\.example\.com.*token|login\/oauth2\/token/)
          .to_return(
            status: 200,
            body:   { access_token: "fake_token_abc", token_type: "Bearer" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub score POST
        stub_request(:post, "https://canvas.example.com/api/lti/courses/1/line_items/1/scores")
          .to_return(
            status: 200,
            body:   { resultUrl: "https://canvas.example.com/results/1" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "marks the submission as submitted" do
        service.call
        expect(submission.reload.status).to eq("submitted")
      end

      it "sets submitted_at" do
        service.call
        expect(submission.reload.submitted_at).to be_present
      end

      it "increments attempt_count" do
        service.call
        expect(submission.reload.attempt_count).to eq(1)
      end

      it "stores the canvas response" do
        service.call
        expect(submission.reload.canvas_response).to include("resultUrl")
      end
    end

    context "when the token request fails" do
      before do
        stub_request(:post, /login\/oauth2\/token/)
          .to_return(status: 401, body: "Unauthorized")
      end

      it "raises PassbackError" do
        expect { service.call }.to raise_error(GradePassbackService::PassbackError, /Token request failed/)
      end

      it "increments attempt_count" do
        service.call rescue nil
        expect(submission.reload.attempt_count).to eq(1)
      end

      it "stores the error message" do
        service.call rescue nil
        expect(submission.reload.error_message).to be_present
      end
    end

    context "when the score POST fails" do
      before do
        stub_request(:post, /login\/oauth2\/token/)
          .to_return(
            status: 200,
            body:   { access_token: "token" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        stub_request(:post, /line_items.*scores/)
          .to_return(status: 422, body: "Unprocessable Entity")
      end

      it "raises PassbackError" do
        expect { service.call }.to raise_error(GradePassbackService::PassbackError, /Score POST failed/)
      end
    end

    context "when lineitem_url is blank" do
      before { lti_launch.update!(lineitem_url: nil) }

      it "raises PassbackError before making any HTTP calls" do
        stub_request(:post, /login\/oauth2\/token/)
          .to_return(status: 200, body: { access_token: "token" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        expect { service.call }.to raise_error(GradePassbackService::PassbackError, /No lineitem_url/)
      end
    end
  end
end
