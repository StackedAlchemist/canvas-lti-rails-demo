class Rack::Attack
  # Rate limit AI chat: 20 requests per student per hour
  # Key is the lti_launch_id pulled from the Rack session
  throttle("ai/chat/per_student", limit: 20, period: 1.hour) do |req|
    if req.path == "/ai/chat" && req.post?
      session_data = req.env["rack.session"]
      session_data&.[]("lti_launch_id")
    end
  end

  throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Rate limit exceeded. You can send up to 20 messages per hour." }.to_json ]
    ]
  end

  self.throttled_responder = throttled_responder
end
