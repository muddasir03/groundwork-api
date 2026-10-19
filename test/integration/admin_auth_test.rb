require "test_helper"

class AdminAuthTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    clear_rate_limits
    @admin = create_admin
  end

  def login(email: @admin.email_address, password: ADMIN_PASSWORD)
    post api_v1_admin_session_path, params: { emailAddress: email, password: password }, as: :json
  end

  test "logging in returns a token once and stores only its digest" do
    @admin = create_admin(email: "setup-pending@example.com", two_factor: false) # one-step login
    login
    assert_response :created
    token = json.dig("data", "token")
    assert_operator token.length, :>=, 40
    assert_equal({ "id" => @admin.id.to_s, "emailAddress" => "setup-pending@example.com", "role" => "admin", "twoFactorEnabled" => false },
                 json.dig("data", "user"))

    stored = Session.last
    assert_equal Digest::SHA256.hexdigest(token), stored.token_digest
    assert_not_includes Session.pluck(:token_digest), token
  end

  test "email matching ignores case and surrounding spaces" do
    login(email: "  ADMIN@Example.com ")
    assert_response :accepted # password accepted; two-factor code next
  end

  test "wrong password, unknown email and non-admin accounts get the same answer" do
    create_admin(email: "member@example.com", role: :member)
    bodies = [
      login(password: "wrong password!!"), response.body,
      login(email: "nobody@example.com"), response.body,
      login(email: "member@example.com"), response.body
    ].each_slice(2).map(&:last)

    assert_response :unauthorized
    assert_equal 1, bodies.uniq.size, "responses differ, which would reveal which accounts exist"
    assert_equal "invalid_credentials", JSON.parse(bodies.first).dig("error", "code")
  end

  test "a valid token authenticates; missing, malformed or URL tokens don't" do
    headers = admin_headers(@admin)
    get api_v1_admin_session_path, headers: headers
    assert_response :ok

    token = headers["Authorization"].delete_prefix("Bearer ")
    get api_v1_admin_session_path
    assert_response :unauthorized
    get api_v1_admin_session_path, params: { token: token }
    assert_response :unauthorized, "tokens must not be accepted from the URL"
    get api_v1_admin_session_path, headers: { "Authorization" => "Bearer not-a-real-token" }
    assert_response :unauthorized
    get api_v1_admin_session_path, headers: { "Authorization" => "Basic #{token}" }
    assert_response :unauthorized
  end

  test "sessions expire after 8 hours, even when used all along" do
    headers = admin_headers(@admin)
    # Use it every 90 minutes (inside the idle limit) until just before the 8-hour mark.
    5.times do
      travel 90.minutes
      get api_v1_admin_session_path, headers: headers
      assert_response :ok
    end
    travel 31.minutes # 8h01m after login
    get api_v1_admin_session_path, headers: headers
    assert_response :unauthorized
  ensure
    travel_back
  end

  test "sessions expire after 2 idle hours" do
    headers = admin_headers(@admin)
    travel 2.hours + 1.minute do
      get api_v1_admin_session_path, headers: headers
      assert_response :unauthorized
    end
  end

  test "logging out revokes the token on the server" do
    headers = admin_headers(@admin)
    delete api_v1_admin_session_path, headers: headers
    assert_response :no_content
    get api_v1_admin_session_path, headers: headers
    assert_response :unauthorized
  end

  test "a logged-in non-admin is forbidden from admin endpoints" do
    member = create_admin(email: "member@example.com", role: :member)
    session, token = Session.start!(user: member)
    get api_v1_admin_companies_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :forbidden
    assert session.persisted?
  end

  test "limits login attempts per email, even with the right password afterwards" do
    3.times { login(password: "wrong password!!") }
    login
    assert_response :too_many_requests
    assert_equal "rate_limited", json.dig("error", "code")
  end

  test "limits login attempts per IP across different emails" do
    4.times { |i| login(email: "guess#{i}@example.com", password: "wrong password!!") }
    login
    assert_response :too_many_requests
  end

  test "records logins, failed logins and logouts in the audit log" do
    login(password: "wrong password!!")
    headers = admin_headers(@admin)
    delete api_v1_admin_session_path, headers: headers
    actions = AuditEvent.order(:id).pluck(:action) - %w[admin.two_factor_setup_started admin.two_factor_enabled]
    assert_equal %w[admin.login_failed admin.login_password_ok admin.login admin.logout], actions
    assert_equal "admin@example.com", AuditEvent.find_by(action: "admin.login_failed").details["email"]
  end

  test "admin responses are never cached and never include secrets" do
    headers = admin_headers(@admin)
    get api_v1_admin_session_path, headers: headers
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_no_match(/digest|password/i, response.body)
  end

  test "audit events can't be edited" do
    login(password: "wrong password!!")
    assert_raises(ActiveRecord::ReadOnlyRecord) { AuditEvent.last.update!(action: "tampered") }
  end

  private

  def json = response.parsed_body
end
