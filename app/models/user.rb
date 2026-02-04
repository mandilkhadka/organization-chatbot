class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable

  enum role: { employee: 0, admin: 1 }

  has_many :documents, dependent: :destroy
  has_many :conversations, dependent: :destroy

  validate :cannot_remove_last_admin, on: :update, if: :role_changed?
  before_destroy :ensure_not_last_admin

  def admin?
    role == "admin"
  end

  def last_admin?
    admin? && User.admin.one?
  end

  def admin_session_expired?
    return false unless admin?
    return true if admin_session_expires_at.nil?

    admin_session_expires_at < Time.current
  end

  def refresh_admin_session!(timeout_minutes: nil)
    timeout_minutes ||= ENV.fetch("ADMIN_SESSION_TIMEOUT_MINUTES", 30).to_i
    update!(admin_session_expires_at: timeout_minutes.minutes.from_now)
  end

  def clear_admin_session!
    update!(admin_session_expires_at: nil)
  end

  # Only refresh session if within threshold of expiration
  # This prevents unnecessary database writes on every request
  def refresh_admin_session_if_needed!(timeout_minutes: nil, refresh_threshold_minutes: nil)
    return unless admin?
    return if admin_session_expires_at.nil?

    timeout_minutes ||= ENV.fetch("ADMIN_SESSION_TIMEOUT_MINUTES", 30).to_i
    refresh_threshold_minutes ||= ENV.fetch("ADMIN_SESSION_REFRESH_THRESHOLD_MINUTES", 5).to_i

    # Only refresh if session expires within the threshold
    if admin_session_expires_at < refresh_threshold_minutes.minutes.from_now
      refresh_admin_session!(timeout_minutes: timeout_minutes)
    end
  end

  private

  def cannot_remove_last_admin
    return unless role_was == "admin" && role != "admin"
    return unless User.admin.one?

    errors.add(:role, "cannot be changed. You are the last admin.")
  end

  def ensure_not_last_admin
    return unless last_admin?

    errors.add(:base, "Cannot delete the last admin user")
    throw(:abort)
  end
end
