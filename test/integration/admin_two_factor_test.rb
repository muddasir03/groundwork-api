require "test_helper"

class AdminTwoFactorTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    clear_rate_limits
    @admin = create_admin
  end

  def password_step(user = @admin)
    post api_v1_admin_session_path, params: { emailAddress: user.email_address, password: ADMIN_PASSWORD }, as: :json
    json.dig("data", "challengeToken")
  end

  def verify(challenge, **params)
    post verify_api_v1_admin_session_path, params: { challengeToken: challenge, **params }, as: :json
  end

  # ── Login ──────────────────────────────────────────────────────────────────────────────────────

  test "a correct password alone gives a challenge, not a session" do
    assert_no_difference -> { Session.count } do
      challenge = password_step
      assert_response :accepted
      assert json.dig("data", "twoFactorRequired")
      assert_operator challenge.length, :>=, 40
    end
  end

  test "a valid code turns the challenge into a session, once" do
    challenge = password_step
    verify(challenge, code: current_code(@admin))
    assert_response :created
    assert json.dig("data", "user", "twoFactorEnabled")

    allow_code_reuse(@admin)
    verify(challenge, code: current_code(@admin))
    assert_response :unauthorized, "a challenge must not be reusable"
  end

  test "the challenge token is not a session token" do
    challenge = password_step
    get api_v1_admin_session_path, headers: { "Authorization" => "Bearer #{challenge}" }
    assert_response :unauthorized
  end

  test "a wrong code is refused, and five wrong codes kill the challenge" do
    challenge = password_step
    5.times do
      verify(challenge, code: "000000")
      assert_response :unauthorized
      assert_equal "invalid_code", json.dig("error", "code")
    end
    verify(challenge, code: current_code(@admin))
    assert_response :unauthorized, "the right code must not work after too many wrong ones"
  end

  test "challenges expire after five minutes" do
    challenge = password_step
    travel 5.minutes + 1.second do
      verify(challenge, code: current_code(@admin))
      assert_response :unauthorized
    end
  end

  test "a code can't be used twice (no replay)" do
    code = current_code(@admin)
    verify(password_step, code: code)
    assert_response :created

    verify(password_step, code: code) # same code, new login, same 30 s window
    assert_response :unauthorized
  end

  test "a recovery code logs in once" do
    codes = @admin.regenerate_recovery_codes!
    verify(password_step, recoveryCode: codes.first.upcase) # case and dash don't matter
    assert_response :created
    assert_equal "recovery_code", AuditEvent.where(action: "admin.login").last.details["method"]

    verify(password_step, recoveryCode: codes.first)
    assert_response :unauthorized
  end

  test "code guessing is rate limited per IP too" do
    challenge = password_step
    Rails.configuration.x.two_factor_rate_limit_per_ip.times { verify(password_step, code: "000000") }
    verify(challenge, code: current_code(@admin))
    assert_response :too_many_requests
  end

  test "malformed codes are refused without errors" do
    challenge = password_step
    [ "12345", "1234567", "abcdef", "", "1" * 500 ].each do |code|
      verify(challenge, code: code)
      assert_response :unauthorized
    end
    verify(password_step, recoveryCode: "<script>")
    assert_response :unauthorized
  end

  # ── Enforcement and setup ──────────────────────────────────────────────────────────────────────

  test "an admin without two-factor can only set it up" do
    newcomer = create_admin(email: "new@example.com", two_factor: false)
    headers = admin_headers(newcomer)

    get api_v1_admin_companies_path, headers: headers
    assert_response :forbidden
    assert_equal "two_factor_setup_required", json.dig("error", "code")

    get api_v1_admin_session_path, headers: headers
    assert_response :ok
    assert_not json.dig("data", "user", "twoFactorEnabled")
    get api_v1_admin_two_factor_path, headers: headers
    assert_response :ok
  end

  test "setting up two-factor: QR image, wrong code refused, right code gives recovery codes" do
    newcomer = create_admin(email: "new@example.com", two_factor: false)
    headers = admin_headers(newcomer)

    post setup_api_v1_admin_two_factor_path, headers: headers
    assert_response :ok
    assert json.dig("data", "qrCodeDataUri").start_with?("data:image/svg+xml;base64,")
    assert json.dig("data", "otpauthUri").start_with?("otpauth://totp/Groundwork:")
    secret = json.dig("data", "secret")

    post confirm_api_v1_admin_two_factor_path, headers: headers, params: { code: "000000" }, as: :json
    assert_response :unprocessable_content

    post confirm_api_v1_admin_two_factor_path, headers: headers, params: { code: ROTP::TOTP.new(secret).now }, as: :json
    assert_response :ok
    assert_equal 10, json.dig("data", "recoveryCodes").size
    assert_equal "admin.two_factor_enabled", AuditEvent.last.action

    get api_v1_admin_companies_path, headers: headers
    assert_response :ok, "the session that set it up keeps working"
  end

  test "turning two-factor on ends every other session" do
    newcomer = create_admin(email: "new@example.com", two_factor: false)
    other = admin_headers(newcomer) # e.g. someone else who knew the password
    mine = admin_headers(newcomer)

    post setup_api_v1_admin_two_factor_path, headers: mine
    post confirm_api_v1_admin_two_factor_path, headers: mine, params: { code: ROTP::TOTP.new(json.dig("data", "secret")).now }, as: :json
    assert_response :ok

    get api_v1_admin_session_path, headers: other
    assert_response :unauthorized
  end

  test "setup can't replace an existing authenticator" do
    post setup_api_v1_admin_two_factor_path, headers: admin_headers(@admin)
    assert_response :conflict
  end

  test "new recovery codes need a valid code" do
    headers = admin_headers(@admin)
    allow_code_reuse(@admin)
    post recovery_codes_api_v1_admin_two_factor_path, headers: headers, params: { code: "000000" }, as: :json
    assert_response :unprocessable_content

    post recovery_codes_api_v1_admin_two_factor_path, headers: headers, params: { code: current_code(@admin) }, as: :json
    assert_response :ok
    assert_equal 10, json.dig("data", "recoveryCodes").size
  end

  # ── Storage ────────────────────────────────────────────────────────────────────────────────────

  test "secrets are encrypted and recovery codes hashed in the database" do
    secret = @admin.reload.otp_secret
    raw = User.connection.select_value("SELECT otp_secret FROM users WHERE id = #{@admin.id}")
    assert_not_includes raw, secret

    codes = @admin.regenerate_recovery_codes!
    stored = @admin.recovery_codes.pluck(:code_digest)
    codes.each { |code| assert_not_includes stored, code.delete("-") }
    assert stored.all? { it.start_with?("$2a$") }, "recovery codes must be bcrypt hashes"
  end

  test "responses never contain secrets, except the one-time setup screen" do
    headers = admin_headers(@admin)
    [ api_v1_admin_session_path, api_v1_admin_two_factor_path ].each do |path|
      get path, headers: headers
      assert_no_match(/otp|secret|digest/i, response.body)
    end
  end

  test "the reset task turns two-factor off and ends sessions" do
    require "rake"
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    headers = admin_headers(@admin)
    ENV["EMAIL"] = @admin.email_address
    Rake::Task["admin:reset_two_factor"].reenable
    capture_io { Rake::Task["admin:reset_two_factor"].invoke }

    assert_not @admin.reload.two_factor_enabled?
    get api_v1_admin_session_path, headers: headers
    assert_response :unauthorized
  ensure
    ENV.delete("EMAIL")
  end

  private

  def json = response.parsed_body
end
