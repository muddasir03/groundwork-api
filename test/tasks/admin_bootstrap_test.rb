require "test_helper"
require "rake"

class AdminBootstrapTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @env = ENV.to_h.slice("ADMIN_BOOTSTRAP_EMAIL", "ADMIN_BOOTSTRAP_PASSWORD")
  end

  teardown do
    ENV.delete("ADMIN_BOOTSTRAP_EMAIL")
    ENV.delete("ADMIN_BOOTSTRAP_PASSWORD")
    ENV.update(@env)
  end

  def bootstrap(email:, password:)
    ENV["ADMIN_BOOTSTRAP_EMAIL"] = email
    ENV["ADMIN_BOOTSTRAP_PASSWORD"] = password
    task = Rake::Task["admin:bootstrap"]
    task.reenable
    capture_io { task.invoke }.first
  end

  test "creates the first admin when none exists" do
    output = bootstrap(email: "first@example.com", password: "a long enough password")
    assert User.find_by(email_address: "first@example.com")&.admin?
    assert_match "created the first admin", output
    assert_no_match "a long enough password", output
  end

  test "never creates a second admin or touches an existing one" do
    existing = User.create!(email_address: "owner@example.com", password: "the owners password", role: :admin)
    output = bootstrap(email: "owner@example.com", password: "attacker chosen password")
    assert_match "an admin already exists", output
    assert existing.reload.authenticate("the owners password"), "existing password must not change"

    bootstrap(email: "second@example.com", password: "another long password")
    assert_nil User.find_by(email_address: "second@example.com")
  end

  test "refuses a weak password without printing it" do
    output = bootstrap(email: "first@example.com", password: "short")
    assert_nil User.find_by(email_address: "first@example.com")
    assert_match "too short", output
    assert_no_match(/\bshort\b.*\bshort\b/, output.sub("too short", ""))
  end
end
