class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  # Enrich lograge payload with identity so we can grep logs by user.
  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.request_id
    payload[:remote_ip] = request.remote_ip
    payload[:user_id] = current_user&.id if respond_to?(:current_user)
  end
end
