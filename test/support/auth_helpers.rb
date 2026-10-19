require "rotp"

module AuthHelpers
  ADMIN_PASSWORD = "correct horse battery staple"

  # An admin with two-factor login on (the normal case). Pass two_factor: false for one who hasn't
  # set it up yet.
  def create_admin(email: "admin@example.com", role: :admin, two_factor: true)
    user = User.create!(email_address: email, password: ADMIN_PASSWORD, role: role)
    enable_two_factor(user) if two_factor
    user
  end

  def enable_two_factor(user)
    secret = user.start_two_factor_setup![:secret]
    user.confirm_two_factor!(ROTP::TOTP.new(secret).now)
    allow_code_reuse(user)
    user
  end

  def current_code(user) = ROTP::TOTP.new(user.reload.otp_secret).now

  # Codes work once per 30-second step. Tests log in many times within one step, so they clear the
  # marker first; replay protection itself is tested separately.
  def allow_code_reuse(user) = user.update_column(:otp_last_used_step, nil)

  # Logs in through the real endpoints (password, then code) and returns the Authorization header.
  def admin_headers(user = create_admin)
    post api_v1_admin_session_path, params: { emailAddress: user.email_address, password: ADMIN_PASSWORD }, as: :json
    if response.status == 202
      challenge = response.parsed_body.dig("data", "challengeToken")
      allow_code_reuse(user)
      post verify_api_v1_admin_session_path, params: { challengeToken: challenge, code: current_code(user) }, as: :json
    end
    raise "login failed: #{response.status} #{response.body}" unless response.status == 201

    { "Authorization" => "Bearer #{response.parsed_body.dig('data', 'token')}" }
  end

  def clear_rate_limits
    Rails.configuration.x.api_rate_limit_store.clear
  end
end
