class HomeController < ApplicationController
  def show
  end

  def simulate_launch
    role = params[:role] == "teacher" ? "teacher" : "student"

    roles_claim = if role == "teacher"
      "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
    else
      "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
    end

    lti_launch = LtiLaunch.create!(
      user_id:        "demo_user_#{role}",
      canvas_user_id: "demo_user_#{role}",
      course_id:      "demo_course_456",
      roles:          roles_claim,
      canvas_domain:  request.host,
      raw_jwt_claims: {
        "https://purl.imsglobal.org/spec/lti/claim/context" => {
          "id"    => "demo_course_456",
          "title" => "Demo Course — Introduction to Rails"
        }
      }
    )

    session[:lti_launch_id] = lti_launch.id
    redirect_to dashboard_path
  end
end
