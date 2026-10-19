module Api
  module V1
    module Admin
      # Admin login (password, then a two-factor code) and logout.
      #
      #   POST   /api/v1/admin/session         { emailAddress, password }
      #          → 202 { data: { twoFactorRequired: true, challengeToken, expiresAt } } when 2FA is on
      #          → 201 { data: { token, expiresAt, user } } only while 2FA isn't set up yet (that
      #            session can do nothing but set it up)
      #   POST   /api/v1/admin/session/verify  { challengeToken, code } or { challengeToken, recoveryCode }
      #          → 201 { data: { token, expiresAt, user } }
      #   GET    /api/v1/admin/session         → { data: { expiresAt, user } }
      #   DELETE /api/v1/admin/session         → 204
      class SessionsController < BaseController
        skip_before_action :authenticate!, :require_admin!, :require_two_factor!, only: %i[create verify]
        skip_before_action :require_two_factor!, only: %i[show destroy]

        # Slow down password guessing two ways: per client IP, and per targeted email address (which
        # also covers attacks spread across many IPs).
        rate_limit to: Rails.configuration.x.login_rate_limit_per_ip, within: 1.minute, name: "login-ip",
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: :create,
                   with: -> { too_many_attempts }
        rate_limit to: Rails.configuration.x.login_rate_limit_per_email, within: 15.minutes, name: "login-email",
                   by: -> { login_email.presence || request.remote_ip },
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: :create,
                   with: -> { too_many_attempts }
        # Code guessing is also capped per challenge (LoginChallenge::MAX_ATTEMPTS).
        rate_limit to: Rails.configuration.x.two_factor_rate_limit_per_ip, within: 1.minute, name: "verify-ip",
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: :verify,
                   with: -> { too_many_attempts }

        def create
          # authenticate_by takes the same time whether or not the email exists, so response timing
          # doesn't reveal which addresses have accounts.
          user = User.authenticate_by(email_address: login_email, password: params[:password].to_s)

          # Same answer for unknown email, wrong password, and non-admin: never reveal which it was.
          unless user&.admin?
            AuditEvent.record!("admin.login_failed", user: user, ip_address: request.remote_ip, email: login_email.first(254))
            return render_error(:unauthorized, "invalid_credentials", "That email and password don't match an admin account.")
          end

          # With two-factor on, a correct password only earns a short-lived challenge, not a session.
          if user.two_factor_enabled?
            challenge, challenge_token = LoginChallenge.start!(user: user, ip_address: request.remote_ip)
            AuditEvent.record!("admin.login_password_ok", user: user, ip_address: request.remote_ip)
            return render json: { data: { twoFactorRequired: true, challengeToken: challenge_token, expiresAt: challenge.expires_at.iso8601 } },
                          status: :accepted
          end

          start_session(user, method: "password")
        end

        def verify
          challenge = LoginChallenge.find_usable(params[:challengeToken].to_s)
          return invalid_code unless challenge

          user = challenge.user
          method = if params[:recoveryCode].present?
            "recovery_code" if user.use_recovery_code!(params[:recoveryCode].to_s)
          elsif user.verify_two_factor_code!(params[:code].to_s.strip)
            "totp"
          end

          unless method
            challenge.record_failure!
            AuditEvent.record!("admin.two_factor_failed", user: user, ip_address: request.remote_ip)
            return invalid_code
          end

          challenge.consume!
          start_session(user, method: method)
        end

        def show
          render json: { data: { expiresAt: Current.session.expires_at.iso8601, user: Current.user.as_api_json } }
        end

        def destroy
          Current.session.revoke!
          audit!("admin.logout", subject: Current.session)
          head :no_content
        end

        private

        def start_session(user, method:)
          session, token = ::Session.start!(user: user, ip_address: request.remote_ip, user_agent: request.user_agent)
          AuditEvent.record!("admin.login", user: user, subject: session, ip_address: request.remote_ip, method: method)
          render json: { data: { token: token, expiresAt: session.expires_at.iso8601, user: user.as_api_json } }, status: :created
        end

        def login_email
          params[:emailAddress].to_s.strip.downcase.first(254)
        end

        def invalid_code
          render_error(:unauthorized, "invalid_code", "That code didn't work. Check the code and try again, or log in again.")
        end

        def too_many_attempts
          render_error(:too_many_requests, "rate_limited", "Too many login attempts. Wait a few minutes and try again.")
        end
      end
    end
  end
end
