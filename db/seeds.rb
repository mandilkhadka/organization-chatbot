# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Rails.logger.debug "Setting up seed data..."

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD") do
  if Rails.env.production?
    SecureRandom.alphanumeric(16).tap do |_pass|
      Rails.logger.debug "⚠️  No ADMIN_PASSWORD set. Generated secure password."
      Rails.logger.debug "   SAVE THIS PASSWORD - it won't be shown again!"
    end
  else
    "Admin123Dev456" # Meets 12+ char minimum
  end
end

admin = User.find_or_initialize_by(email: admin_email)
if admin.new_record?
  admin.password = admin_password
  admin.role = :admin
  admin.save!
  Rails.logger.debug { "✓ Admin user created: #{admin.email}" }
  if Rails.env.development?
    Rails.logger.debug { "  Password: #{admin_password}" }
  else
    Rails.logger.debug "  Password: [hidden - set via ADMIN_PASSWORD env var]"
  end
  Rails.logger.debug "  (Change this password immediately in production!)"
elsif admin.admin?
  # Ensure the existing user is an admin
  Rails.logger.debug { "✓ Admin user already exists: #{admin.email}" }
else
  admin.update!(role: :admin)
  Rails.logger.debug { "✓ Updated #{admin.email} to admin role" }
end

Rails.logger.debug ""
Rails.logger.debug "=" * 50
Rails.logger.debug "ADMIN CREDENTIALS"
Rails.logger.debug "=" * 50
Rails.logger.debug { "Email:    #{admin_email}" }
if Rails.env.development?
  Rails.logger.debug { "Password: #{admin_password}" }
else
  Rails.logger.debug "Password: [hidden in production - check ADMIN_PASSWORD env var or logs during generation]"
end
Rails.logger.debug ""
Rails.logger.debug "Admin login: /admin/login"
Rails.logger.debug "Employee login: /users/sign_in"
Rails.logger.debug "=" * 50
Rails.logger.debug ""
Rails.logger.debug "Seed data loaded successfully!"
