class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  private

  def require_lti_launch
    launch_id   = session[:lti_launch_id]
    @lti_launch = LtiLaunch.find_by(id: launch_id) if launch_id

    return if @lti_launch

    respond_to do |format|
      format.html { render "errors/no_lti_session", status: :unauthorized, layout: "application" }
      format.json { render json: { error: "No active LTI session." }, status: :unauthorized }
    end
  end

  def require_instructor
    return if @lti_launch&.instructor?

    respond_to do |format|
      format.html { render plain: "Instructor access required.", status: :forbidden }
      format.json { render json: { error: "Instructor access required." }, status: :forbidden }
    end
  end
end
