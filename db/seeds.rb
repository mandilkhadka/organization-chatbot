# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Setting up seed data..."

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD") do
  if Rails.env.production?
    SecureRandom.alphanumeric(16).tap do |pass|
      puts "⚠️  No ADMIN_PASSWORD set. Generated secure password."
      puts "   SAVE THIS PASSWORD - it won't be shown again!"
    end
  else
    "admin123" # Only use weak password in development
  end
end

admin = User.find_or_initialize_by(email: admin_email)
if admin.new_record?
  admin.password = admin_password
  admin.role = :admin
  admin.save!
  puts "✓ Admin user created: #{admin.email}"
  if Rails.env.development?
    puts "  Password: #{admin_password}"
  else
    puts "  Password: [hidden - set via ADMIN_PASSWORD env var]"
  end
  puts "  (Change this password immediately in production!)"
else
  # Ensure the existing user is an admin
  unless admin.admin?
    admin.update!(role: :admin)
    puts "✓ Updated #{admin.email} to admin role"
  else
    puts "✓ Admin user already exists: #{admin.email}"
  end
end

puts ""
puts "=" * 50
puts "ADMIN CREDENTIALS"
puts "=" * 50
puts "Email:    #{admin_email}"
if Rails.env.development?
  puts "Password: #{admin_password}"
else
  puts "Password: [hidden in production - check ADMIN_PASSWORD env var or logs during generation]"
end
puts ""
puts "Login at: /users/sign_in"
puts "Admin panel: /admin"
puts "=" * 50
puts ""
puts "Seed data loaded successfully!"
