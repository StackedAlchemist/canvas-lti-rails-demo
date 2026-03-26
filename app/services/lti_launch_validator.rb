require "jwt"

class LtiLaunchValidator
  CACHE_TTL = 5.minutes

  class ValidationError < StandardError; end

  def initialize(id_token)
    @id_token = id_token
  end

  def validate!
    jwks = fetch_jwks
    claims, = JWT.decode(@id_token, nil, true, algorithms: ["RS256"], jwks: { keys: jwks }) do |header, _payload|
      find_key(jwks, header["kid"])
    end

    validate_claims!(claims)
    claims
  rescue JWT::DecodeError => e
    raise ValidationError, "JWT decode failed: #{e.message}"
  end

  private

  def fetch_jwks
    cache_key = "lti_jwks"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    response = HTTParty.get(LtiConfig::JWKS_URL, timeout: 10)
    raise ValidationError, "Failed to fetch JWKS: HTTP #{response.code}" unless response.success?

    jwks = response.parsed_response["keys"]
    Rails.cache.write(cache_key, jwks, expires_in: CACHE_TTL)
    jwks
  rescue HTTParty::Error => e
    raise ValidationError, "JWKS fetch error: #{e.message}"
  end

  def find_key(jwks, kid)
    key_data = jwks.find { |k| k["kid"] == kid }
    raise ValidationError, "No matching JWK found for kid: #{kid}" unless key_data

    JWT::JWK.import(key_data).public_key
  end

  def validate_claims!(claims)
    raise ValidationError, "Missing iss"          unless claims["iss"].present?
    raise ValidationError, "Missing sub"          unless claims["sub"].present?
    raise ValidationError, "Missing azp/client_id" unless claims["azp"].present? || claims["aud"].present?

    aud = Array(claims["aud"])
    unless aud.include?(LtiConfig::CLIENT_ID)
      raise ValidationError, "client_id mismatch: #{aud.inspect}"
    end

    deployment_id = claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    if LtiConfig::DEPLOYMENT_ID.present? && deployment_id != LtiConfig::DEPLOYMENT_ID
      raise ValidationError, "deployment_id mismatch"
    end
  end
end
