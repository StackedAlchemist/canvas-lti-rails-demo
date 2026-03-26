require "rails_helper"

RSpec.describe DashboardController, type: :controller do
  let(:student_launch) do
    create(:lti_launch,
      roles:          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      canvas_user_id: "student_001",
      course_id:      "course_abc",
      raw_jwt_claims: {
        "https://purl.imsglobal.org/spec/lti/claim/context" => {
          "id"    => "course_abc",
          "title" => "Intro to Rails"
        }
      }
    )
  end

  let(:instructor_launch) do
    create(:lti_launch,
      roles:          "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
      canvas_user_id: "instructor_001",
      course_id:      "course_abc",
      raw_jwt_claims: {
        "https://purl.imsglobal.org/spec/lti/claim/context" => {
          "id"    => "course_abc",
          "title" => "Intro to Rails"
        }
      }
    )
  end

  describe "GET #show" do
    context "with no LTI session" do
      it "returns 401" do
        get :show
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "as a student" do
      before { session[:lti_launch_id] = student_launch.id }

      it "returns 200" do
        get :show
        expect(response).to have_http_status(:ok)
      end

      it "creates a StudentProgress record for the user" do
        expect { get :show }.to change(StudentProgress, :count).by(1)
      end

      it "does not create a duplicate record on second visit" do
        get :show
        expect { get :show }.not_to change(StudentProgress, :count)
      end

      it "sets @is_student to true and @is_instructor to false" do
        get :show
        expect(assigns(:is_student)).to be true
        expect(assigns(:is_instructor)).to be false
      end

      it "sets @course_name from JWT claims" do
        get :show
        expect(assigns(:course_name)).to eq("Intro to Rails")
      end
    end

    context "as an instructor" do
      before { session[:lti_launch_id] = instructor_launch.id }

      it "returns 200" do
        get :show
        expect(response).to have_http_status(:ok)
      end

      it "sets @is_instructor to true and @is_student to false" do
        get :show
        expect(assigns(:is_instructor)).to be true
        expect(assigns(:is_student)).to be false
      end
    end
  end
end
