module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      warden = env["warden"]
      return reject_unauthorized_connection if warden.nil?

      if (verified_user = warden.user)
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
