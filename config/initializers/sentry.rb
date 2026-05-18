# Sentry is opt-in: it only initializes when SENTRY_DSN is set, so dev/test
# stay silent unless an operator wires it up.
return unless ENV["SENTRY_DSN"].present?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  config.environment = Rails.env
  config.release = ENV["GIT_SHA"] || ENV["HEROKU_SLUG_COMMIT"]
  config.enabled_environments = %w[production staging]

  config.send_default_pii = false
  # Performance traces — keep low in prod to control volume.
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.05").to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.05").to_f

  # Don't ship noise.
  config.excluded_exceptions += %w[
    ActionController::RoutingError
    ActiveRecord::RecordNotFound
    Rack::QueryParser::InvalidParameterError
    Rack::QueryParser::ParameterTypeError
  ]

  # PII scrubber — never let request params/headers carry credentials.
  config.before_send = lambda do |event, _hint|
    if event.request
      event.request.headers&.except!("Authorization", "Cookie", "X-Api-Key")
      event.request.data = scrub_params(event.request.data)
    end
    event
  end
end

SENSITIVE_KEYS = %w[
  password password_confirmation current_password
  token api_key gemini_api_key authenticity_token
  credit_card cvv ssn
].freeze

def scrub_params(value)
  case value
  when Hash
    value.each_with_object({}) do |(k, v), memo|
      memo[k] = SENSITIVE_KEYS.include?(k.to_s.downcase) ? "[FILTERED]" : scrub_params(v)
    end
  when Array
    value.map { |v| scrub_params(v) }
  else
    value
  end
end
