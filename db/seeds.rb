# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin_password = ENV.fetch("ADMIN_PASSWORD", "change_me_in_production")
admin = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = admin_password
  user.role = :admin
end
puts "Admin user created: #{admin.email}"

# Create a regular employee user
employee_password = ENV.fetch("EMPLOYEE_PASSWORD", "change_me_in_production")
employee = User.find_or_create_by!(email: "employee@example.com") do |user|
  user.password = employee_password
  user.role = :employee
end
puts "Employee user created: #{employee.email}"

puts "Seed data loaded successfully!"
