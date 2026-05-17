module Auditable
  extend ActiveSupport::Concern

  SENSITIVE_FIELDS = %w[
    updated_at created_at encrypted_password
    reset_password_token reset_password_sent_at
    unlock_token locked_at remember_created_at
  ].freeze

  included do
    after_action :log_admin_action, if: :should_audit?
  end

  private

  def should_audit?
    current_user&.admin? && action_auditable?
  end

  def action_auditable?
    %w[create update destroy bulk_create].include?(action_name)
  end

  def log_admin_action
    return unless @audited_resource || @audited_resources

    action = map_action_name
    change_data = extract_changes

    if @audited_resources.present?
      @audited_resources.each do |resource|
        AdminAuditLog.log_action(
          user: current_user,
          action: action,
          resource: resource,
          change_data: change_data,
          request: request
        )
      end
    elsif @audited_resource.present?
      AdminAuditLog.log_action(
        user: current_user,
        action: action,
        resource: @audited_resource,
        change_data: change_data,
        request: request
      )
    end
  end

  def map_action_name
    case action_name
    when "create" then "create"
    when "update" then "update"
    when "destroy" then "delete"
    when "bulk_create" then "bulk_create"
    else action_name
    end
  end

  def extract_changes
    return {} unless @audited_resource.respond_to?(:previous_changes)

    @audited_resource.previous_changes.except(*SENSITIVE_FIELDS)
  end

  def audit_resource(resource)
    @audited_resource = resource
  end

  def audit_resources(resources)
    @audited_resources = resources
  end
end
