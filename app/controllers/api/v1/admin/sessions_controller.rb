module Api
  module V1
    module Admin
      # Admin login and logout.
      #
      #   POST   /api/v1/admin/session  { "emailAddress": "...", "password": "..." }  → 201 { data: { token, expiresAt, user } }
      #   GET    /api/v1/admin/session  → 200 { data: { expiresAt, user } }
      #   DELETE /api/v1/admin/session  → 204, and the token stops working
      class SessionsController < BaseController
        skip_before_action :authenticate!, :require_admin!, only: :create

        # Slow down password guessing two ways: per client IP, and per targeted email address (which
        # also covers attacks spread across many IPs).
        rate_limit to: Rails.configuration.x.login_rate_limit_per_ip, within: 1.minute, name: "login-ip",
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: :create,
                   with: -> { too_many_attempts }
        rate_limit to: Rails.configuration.x.login_rate_limit_per_email, within: 15.minutes, name: "login-email",
                   by: -> { login_email.presence || request.remote_ip },
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: :create,
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

          session, token = ::Session.start!(user: user, ip_address: request.remote_ip, user_agent: request.user_agent)
          AuditEvent.record!("admin.login", user: user, subject: session, ip_address: request.remote_ip)
          render json: { data: { token: token, expiresAt: session.expires_at.iso8601, user: user.as_api_json } }, status: :created
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

        def login_email
          params[:emailAddress].to_s.strip.downcase.first(254)
        end

        def too_many_attempts
          render_error(:too_many_requests, "rate_limited", "Too many login attempts. Wait a few minutes and try again.")
        end
      end
    end
  end
end
