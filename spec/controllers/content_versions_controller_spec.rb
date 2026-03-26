require "rails_helper"

RSpec.describe ContentVersionsController, type: :controller do
  let(:instructor_launch) do
    create(:lti_launch,
      roles:          "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
      canvas_user_id: "instructor_001",
      course_id:      "course_abc"
    )
  end

  let(:student_launch) do
    create(:lti_launch,
      roles:          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      canvas_user_id: "student_001",
      course_id:      "course_abc"
    )
  end

  let(:content) { create(:course_content, canvas_course_id: "course_abc") }

  describe "POST #publish" do
    let(:draft) { create(:content_version, course_content: content, status: "draft", version_number: 1) }

    context "as instructor" do
      before { session[:lti_launch_id] = instructor_launch.id }

      it "marks the version as published" do
        post :publish, params: { course_content_id: content.id, id: draft.id }
        expect(draft.reload.status).to eq("published")
      end

      it "sets published_version on the course content" do
        post :publish, params: { course_content_id: content.id, id: draft.id }
        expect(content.reload.published_version).to eq(draft)
      end

      it "redirects to the course content page" do
        post :publish, params: { course_content_id: content.id, id: draft.id }
        expect(response).to redirect_to(course_content_path(content))
      end
    end

    context "as student" do
      before { session[:lti_launch_id] = student_launch.id }

      it "returns 403" do
        post :publish, params: { course_content_id: content.id, id: draft.id }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not change the version status" do
        post :publish, params: { course_content_id: content.id, id: draft.id }
        expect(draft.reload.status).to eq("draft")
      end
    end
  end

  describe "POST #rollback" do
    let!(:source_version) do
      create(:content_version, course_content: content, body: "Old content", version_number: 1)
    end

    context "as instructor" do
      before { session[:lti_launch_id] = instructor_launch.id }

      it "creates a new draft version" do
        expect {
          post :rollback, params: { course_content_id: content.id, id: source_version.id }
        }.to change(ContentVersion, :count).by(1)
      end

      it "new draft has the source body" do
        post :rollback, params: { course_content_id: content.id, id: source_version.id }
        new_draft = ContentVersion.order(version_number: :desc).first
        expect(new_draft.body).to eq("Old content")
        expect(new_draft.status).to eq("draft")
      end

      it "does not alter the original version" do
        post :rollback, params: { course_content_id: content.id, id: source_version.id }
        expect(source_version.reload.body).to eq("Old content")
      end
    end

    context "as student" do
      before { session[:lti_launch_id] = student_launch.id }

      it "returns 403 and does not create a version" do
        expect {
          post :rollback, params: { course_content_id: content.id, id: source_version.id }
        }.not_to change(ContentVersion, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
