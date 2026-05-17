# Rate limiting configuration for security
class Rack::Attack
  # Throttle admin login attempts by IP address
  # Limit to 5 requests per 20 seconds per IP
  throttle("admin_login/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/admin/login" && req.post?
  end

  # Throttle admin login attempts by email
  # Limit to 5 requests per 5 minutes per email
  throttle("admin_login/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/admin/login" && req.post?
      req.params["email"].to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  # Throttle user login attempts by IP address (Devise)
  throttle("user_login/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # Throttle user login attempts by email (Devise)
  throttle("user_login/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  # Throttle password reset requests
  throttle("password_reset/ip", limit: 3, period: 5.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # Throttle document uploads
  throttle("document_upload/user", limit: 20, period: 1.hour) do |req|
    if req.path == "/admin/documents" && req.post?
      req.env["warden"]&.user&.id
    end
  end

  # Throttle bulk uploads more strictly
  throttle("bulk_upload/user", limit: 5, period: 1.hour) do |req|
    if req.path == "/admin/documents/bulk_create" && req.post?
      req.env["warden"]&.user&.id
    end
  end

  # Block suspicious requests (fail2ban style)
  blocklist("fail2ban/admin_login") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 10.minutes, bantime: 1.hour) do
      req.path == "/admin/login" && req.post?
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Rate limit exceeded. Please try again later." }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |request|
    [
      403,
      { "Content-Type" => "application/json" },
      [{ error: "Your IP has been temporarily blocked due to too many failed attempts." }.to_json]
    ]
  end
end

# Enable Rack::Attack in production and development
Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?
