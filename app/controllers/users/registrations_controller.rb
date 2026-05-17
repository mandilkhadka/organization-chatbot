# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :check_registration_allowed, only: %i[new create]

    private

    def check_registration_allowed
      # Only allow public registration if explicitly enabled via environment variable
      # By default, registration is admin-only
      return if ENV['ALLOW_PUBLIC_REGISTRATION'] == 'true'

      # Allow if no users exist yet (for initial setup — first user becomes admin)
      if User.none?
        @initial_setup = true
        return
      end

      flash[:alert] = "Public registration is disabled. Please contact your administrator for an account."
      redirect_to new_user_session_path
    end

    # After Devise creates the user, promote to admin if this is the first user
    def after_sign_up_path_for(resource)
      if User.count == 1 && resource.employee?
        resource.update!(role: :admin)
      end
      super
    end
  end
end
