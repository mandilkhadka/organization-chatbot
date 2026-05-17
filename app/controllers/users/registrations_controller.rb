# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :check_registration_allowed, only: %i[new create]

    private

    def check_registration_allowed
      # Only allow public registration if explicitly enabled via environment variable.
      # By default, registration is admin-only.
      # SECURITY: The User.none? bypass was removed because it created a publicly
      #   reachable "first user becomes admin" race. The first admin must be
      #   created via `bin/rails admin:create` (see lib/tasks/admin.rake).
      return if ENV['ALLOW_PUBLIC_REGISTRATION'] == 'true'

      flash[:alert] = "Public registration is disabled. Please contact your administrator for an account."
      redirect_to new_user_session_path
    end
  end
end
