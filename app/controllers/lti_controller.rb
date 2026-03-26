class LtiController < ApplicationController
  skip_before_action :verify_authenticity_token

  # POST /lti/login — OIDC initiation
  def login
    client_id = params[:client_id]

    unless client_id == LtiConfig::CLIENT_ID
      Rails.logger.warn "[LTI] Login rejected — invalid client_id: #{client_id.inspect}"
      return render plain: "Unauthorized: invalid client_id.", status: :unauthorized
    end

    state = SecureRandom.hex(24)
    nonce = SecureRandom.hex(24)

    session[:lti_state] = state
    session[:lti_nonce] = nonce

    auth_params = {
      scope:            "openid",
      response_type:    "id_token",
      client_id:        LtiConfig::CLIENT_ID,
      redirect_uri:     lti_launch_url,
      login_hint:       params[:login_hint],
      lti_message_hint: params[:lti_message_hint],
      state:            state,
      response_mode:    "form_post",
      nonce:            nonce,
      prompt:           "none"
    }

    Rails.logger.info "[LTI] Login initiated — client_id=#{client_id} login_hint=#{params[:login_hint]}"
    redirect_to "#{LtiConfig::OIDC_AUTH_URL}?#{auth_params.to_query}", allow_other_host: true
  end

  # POST /lti/launch — JWT validation + session creation
  def launch
    unless params[:state] == session[:lti_state]
      Rails.logger.warn "[LTI] Launch rejected — state mismatch"
      return render "errors/lti_launch_failed",
                    status: :unauthorized,
                    locals: { message: "State mismatch. Please try launching the tool again from Canvas." }
    end

    claims = LtiLaunchValidator.new(params[:id_token]).validate!

    lti_launch = LtiLaunch.create!(
      user_id:         claims["sub"],
      canvas_user_id:  claims["sub"],
      course_id:       claims.dig("https://purl.imsglobal.org/spec/lti/claim/context", "id") || "unknown",
      roles:           Array(claims["https://purl.imsglobal.org/spec/lti/claim/roles"]).join(","),
      lineitem_url:    claims.dig("https://purl.imsglobal.org/spec/lti-ags/claim/endpoint", "lineitem"),
      names_roles_url: claims.dig("https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice", "context_memberships_url"),
      canvas_domain:   request.host,
      raw_jwt_claims:  claims
    )

    session[:lti_launch_id] = lti_launch.id
    session.delete(:lti_state)
    session.delete(:lti_nonce)

    Rails.logger.info "[LTI] Launch success — user=#{lti_launch.canvas_user_id} course=#{lti_launch.course_id} roles=#{lti_launch.roles}"
    redirect_to dashboard_path
  rescue LtiLaunchValidator::ValidationError => e
    Rails.logger.error "[LTI] Launch validation failed — #{e.message}"
    render "errors/lti_launch_failed",
           status: :unauthorized,
           locals: { message: "Launch validation failed. Please try again or contact your administrator." }
  end

  # GET /.well-known/jwks.json
  def jwks
    key = LtiConfig.public_key
    jwk = JWT::JWK.new(key).export
    render json: { keys: [jwk] }
  end
end
