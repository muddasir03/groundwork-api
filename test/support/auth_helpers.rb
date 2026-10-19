module AuthHelpers
  ADMIN_PASSWORD = "correct horse battery staple"

  def create_admin(email: "admin@example.com", role: :admin)
    User.create!(email_address: email, password: ADMIN_PASSWORD, role: role)
  end

  # Logs in through the real endpoint and returns the Authorization header.
  def admin_headers(user = create_admin)
    post api_v1_admin_session_path, params: { emailAddress: user.email_address, password: ADMIN_PASSWORD }, as: :json
    raise "login failed: #{response.body}" unless response.status == 201

    { "Authorization" => "Bearer #{response.parsed_body.dig('data', 'token')}" }
  end

  def clear_rate_limits
    Rails.configuration.x.api_rate_limit_store.clear
  end
end
