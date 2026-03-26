require "rails_helper"

RSpec.describe GradePassbackJob do
  let(:submission) { create(:grade_submission, status: "pending") }

  describe "#perform" do
    context "when passback succeeds" do
      it "calls GradePassbackService" do
        service = instance_double(GradePassbackService)
        allow(GradePassbackService).to receive(:new).with(submission).and_return(service)
        allow(service).to receive(:call)

        described_class.new.perform(submission.id)

        expect(service).to have_received(:call)
      end
    end

    context "when submission is already submitted" do
      before { submission.update!(status: "submitted") }

      it "skips calling GradePassbackService" do
        expect(GradePassbackService).not_to receive(:new)
        described_class.new.perform(submission.id)
      end
    end

    context "when PassbackError is raised" do
      it "re-raises so Sidekiq will retry" do
        service = instance_double(GradePassbackService)
        allow(GradePassbackService).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_raise(GradePassbackService::PassbackError, "Canvas timeout")

        expect {
          described_class.new.perform(submission.id)
        }.to raise_error(GradePassbackService::PassbackError)
      end
    end
  end

  describe "sidekiq_retries_exhausted" do
    it "marks the submission as failed when retries are exhausted" do
      msg = { "args" => [submission.id], "error_message" => "Canvas timeout" }
      described_class.sidekiq_retries_exhausted_block.call(msg, RuntimeError.new)
      expect(submission.reload.status).to eq("failed")
      expect(submission.reload.error_message).to include("Max retries exhausted")
    end
  end
end
