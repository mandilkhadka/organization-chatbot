# frozen_string_literal: true

namespace :admin do
  desc "Create an admin user"
  task create: :environment do
    print "Email: "
    email = $stdin.gets.chomp

    print "Password (min 12 chars): "
    password = $stdin.gets.chomp

    user = User.find_or_initialize_by(email: email.downcase)
    user.password = password
    user.password_confirmation = password
    user.role = :admin

    if user.save
      puts "Admin user created: #{user.email}"
    else
      puts "Error: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
