# Single-line JSON request logs. One line per request makes log aggregation
# (Datadog, Loki, CloudWatch) tractable; Rails' multi-line default does not.
Rails.application.configure do
  config.lograge.enabled = !Rails.env.development?
  config.lograge.keep_original_rails_log = false
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    payload = event.payload
    {
      time: Time.current.iso8601(3),
      request_id: payload[:request_id] || payload[:headers]&.dig("action_dispatch.request_id"),
      remote_ip: payload[:remote_ip],
      user_id: payload[:user_id],
      admin_user_id: payload[:admin_user_id],
      params: payload[:params]&.except("controller", "action", "format", "id", "utf8", "authenticity_token"),
      exception: payload[:exception]&.first,
      exception_message: payload[:exception]&.last
    }.compact
  end
end
