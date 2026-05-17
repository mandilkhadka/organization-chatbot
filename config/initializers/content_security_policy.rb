# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :data, "https://cdnjs.cloudflare.com", "https://fonts.gstatic.com", "https://cdn.jsdelivr.net"
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    # SECURITY: Removed :unsafe_inline - using nonces instead for XSS protection
    policy.script_src  :self, "https://cdnjs.cloudflare.com"
    policy.style_src   :self, "https://cdnjs.cloudflare.com", "https://fonts.googleapis.com", "https://cdn.jsdelivr.net"
    # SECURITY: Restrict outbound XHR/fetch/WebSocket targets to known origins.
    # ActionCable WebSocket origin can be overridden via CABLE_HOST.
    cable_host = ENV.fetch('CABLE_HOST', 'localhost')
    policy.connect_src :self,
                       "ws://#{cable_host}:*",
                       "wss://#{cable_host}:*"
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # SECURITY: Generate unique nonce per request using SecureRandom (not session ID)
  # Session-based nonces are predictable and can be exploited if session ID is leaked
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src style-src)

  # Report violations without enforcing the policy (useful for testing).
  # config.content_security_policy_report_only = true
end
