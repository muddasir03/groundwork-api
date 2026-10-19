require "io/console"

# Admin accounts are never created through the API.
namespace :admin do
  desc "Create an admin interactively: bin/rails admin:create EMAIL=you@example.com (prompts for the password)"
  task create: :environment do
    email = ENV["EMAIL"].presence || (print("Email: ") || $stdin.gets.to_s.strip)
    password = $stdin.getpass("Password (12+ characters): ")
    abort "Passwords didn't match." unless password == $stdin.getpass("Repeat password: ")

    user = User.new(email_address: email, password: password, role: :admin)
    abort "Couldn't create admin: #{user.errors.full_messages.to_sentence}" unless user.save

    AuditEvent.record!("admin.create", subject: user, via: "rake")
    puts "Created admin #{user.email_address}."
  end

  # For hosts without a console (Render free plan): runs on every start from bin/render-start.
  # Creates the first admin from ADMIN_BOOTSTRAP_EMAIL / ADMIN_BOOTSTRAP_PASSWORD only while no admin
  # exists. It never changes an existing account, so leftover variables can't take one over.
  # Remove ADMIN_BOOTSTRAP_PASSWORD from the host once the admin can log in.
  desc "Create the first admin from ADMIN_BOOTSTRAP_EMAIL/ADMIN_BOOTSTRAP_PASSWORD if no admin exists"
  task bootstrap: :environment do
    email = ENV["ADMIN_BOOTSTRAP_EMAIL"].to_s.strip
    password = ENV["ADMIN_BOOTSTRAP_PASSWORD"].to_s
    next puts("admin:bootstrap: skipped (variables not set)") if email.empty? || password.empty?
    next puts("admin:bootstrap: skipped (an admin already exists; remove ADMIN_BOOTSTRAP_PASSWORD)") if User.admin.exists?

    user = User.new(email_address: email, password: password, role: :admin)
    if user.save
      AuditEvent.record!("admin.create", subject: user, via: "bootstrap")
      puts "admin:bootstrap: created the first admin. Now remove ADMIN_BOOTSTRAP_PASSWORD from the host."
    else
      # Don't print the password or the full record, only what was wrong.
      puts "admin:bootstrap: not created: #{user.errors.full_messages.to_sentence}"
    end
  end
end
