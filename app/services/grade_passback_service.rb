class GradePassbackService
  class PassbackError < StandardError; end

  def initialize(grade_submission)
    @submission = grade_submission
    @lti_launch = grade_submission.lti_launch
  end

  def call
    Rails.logger.info "[GradePassback] Starting submission #{@submission.id} for user #{@submission.canvas_user_id}"

    token    = fetch_access_token
    response = post_score(token)

    @submission.update!(
      status:          "submitted",
      canvas_response: response,
      submitted_at:    Time.current,
      attempt_count:   @submission.attempt_count + 1
    )

    Rails.logger.info "[GradePassback] Success — submission #{@submission.id} score=#{@submission.score}/#{@submission.max_score}"
    response
  rescue PassbackError => e
    Rails.logger.error "[GradePassback] Failed — submission #{@submission.id}: #{e.message}"
    @submission.update!(
      error_message: e.message,
      attempt_count: @submission.attempt_count + 1
    )
    raise
  end

  private

  def fetch_access_token
    token_url = @lti_launch.raw_jwt_claims
                            .dig("https://purl.imsglobal.org/spec/lti-ags/claim/endpoint", "scope") &&
                build_token_url

    response = HTTParty.post(
      token_url,
      body: {
        grant_type:            "client_credentials",
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion:      build_client_assertion,
        scope:                 ags_scopes
      },
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      timeout: 10
    )

    raise PassbackError, "Token request failed: HTTP #{response.code} — #{response.body}" unless response.success?

    response.parsed_response["access_token"]
  rescue HTTParty::Error => e
    raise PassbackError, "Token fetch error: #{e.message}"
  end

  def post_score(access_token)
    lineitem_url = @lti_launch.lineitem_url
    raise PassbackError, "No lineitem_url on LtiLaunch — cannot submit grade" if lineitem_url.blank?

    scores_url = "#{lineitem_url.chomp("/")}/scores"

    payload = {
      scoreGiven:         @submission.score.to_f,
      scoreMaximum:       @submission.max_score.to_f,
      activityProgress:   @submission.activity_progress,
      gradingProgress:    @submission.grading_progress,
      userId:             @submission.canvas_user_id,
      timestamp:          Time.current.iso8601
    }

    response = HTTParty.post(
      scores_url,
      body:    payload.to_json,
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type"  => "application/vnd.ims.lis.v1.score+json"
      },
      timeout: 15
    )

    raise PassbackError, "Score POST failed: HTTP #{response.code} — #{response.body}" unless response.success?

    response.parsed_response || {}
  rescue HTTParty::Error => e
    raise PassbackError, "Score POST error: #{e.message}"
  end

  def build_token_url
    @lti_launch.raw_jwt_claims.dig(
      "https://purl.imsglobal.org/spec/lti/claim/tool_platform", "token_endpoint"
    ) || "https://#{@lti_launch.canvas_domain}/login/oauth2/token"
  end

  def build_client_assertion
    now     = Time.current.to_i
    payload = {
      iss: LtiConfig::CLIENT_ID,
      sub: LtiConfig::CLIENT_ID,
      aud: build_token_url,
      iat: now,
      exp: now + 300,
      jti: SecureRandom.uuid
    }
    JWT.encode(payload, LtiConfig.private_key, "RS256")
  end

  def ags_scopes
    [
      "https://purl.imsglobal.org/spec/lti-ags/scope/score",
      "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
      "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"
    ].join(" ")
  end
end
