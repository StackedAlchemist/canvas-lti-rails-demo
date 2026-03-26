module LtiConfig
  CLIENT_ID     = ENV.fetch("LTI_CLIENT_ID", nil)
  DEPLOYMENT_ID = ENV.fetch("LTI_DEPLOYMENT_ID", nil)
  OIDC_AUTH_URL = ENV.fetch("CANVAS_OIDC_AUTH_URL", nil)
  JWKS_URL      = ENV.fetch("CANVAS_JWKS_URL", nil)

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.new(ENV["LTI_PRIVATE_KEY"].gsub('\\n', "\n"))
  end

  def self.public_key
    @public_key ||= OpenSSL::PKey::RSA.new(ENV["LTI_PUBLIC_KEY"].gsub('\\n', "\n"))
  end

  REQUIRED_VARS = %w[
    CANVAS_OIDC_AUTH_URL
    CANVAS_JWKS_URL
    LTI_CLIENT_ID
    LTI_DEPLOYMENT_ID
    LTI_PRIVATE_KEY
    LTI_PUBLIC_KEY
  ].freeze

  def self.validate!
    missing = REQUIRED_VARS.select { |var| ENV[var].blank? }
    raise "Missing required LTI environment variables: #{missing.join(', ')}" if missing.any?
  end
end

Rails.application.config.after_initialize do
  missing = LtiConfig::REQUIRED_VARS.select { |var| ENV[var].blank? }
  if missing.any?
    Rails.logger.warn "LTI WARNING: Missing env vars — #{missing.join(', ')}. Set them in .env before using LTI features."
  end
end
