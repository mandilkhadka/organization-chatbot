class AdminAuditLog < ApplicationRecord
  belongs_to :user

  validates :action, presence: true
  validates :resource_type, presence: true

  ACTIONS = %w[login logout session_timeout create update delete bulk_create role_change].freeze

  # Whitelist of allowed resource types to prevent unsafe constantize
  ALLOWED_RESOURCE_TYPES = %w[Document Category User System].freeze

  validates :action, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) if action.present? }
  scope :by_resource_type, ->(type) { where(resource_type: type) if type.present? }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }

  def resource
    return nil unless resource_type.present? && resource_id.present?
    return nil unless ALLOWED_RESOURCE_TYPES.include?(resource_type)

    resource_type.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def self.log_action(user:, action:, resource: nil, change_data: {}, request: nil)
    create!(
      user: user,
      action: action,
      resource_type: resource&.class&.name || "System",
      resource_id: resource&.id,
      change_data: change_data,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent&.truncate(500),
      request_id: request&.request_id
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("CRITICAL: Failed to create audit log: #{e.message}")
    # Report to the Rails error reporter so any subscribed backend (Sentry,
    # Honeybadger, etc.) gets the event. Never swallow silently in any env.
    Rails.error.report(
      e,
      handled: true,
      severity: :error,
      context: {
        audit_user_id: user&.id,
        audit_action: action,
        audit_resource_type: resource&.class&.name,
        audit_resource_id: resource&.id
      }
    )
    raise if Rails.env.development? || Rails.env.test?

    nil
  end
end
