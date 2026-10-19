require "rqrcode"

module Api
  module V1
    module Admin
      # Two-factor setup for the signed-in admin.
      #
      #   GET  /api/v1/admin/two_factor                 → { data: { enabled, enabledAt, remainingRecoveryCodes } }
      #   POST /api/v1/admin/two_factor/setup           → { data: { secret, otpauthUri, qrCodeDataUri } }
      #   POST /api/v1/admin/two_factor/confirm         { code } → { data: { recoveryCodes } }
      #   POST /api/v1/admin/two_factor/recovery_codes  { code } → { data: { recoveryCodes } } (replaces them)
      class TwoFactorController < BaseController
        skip_before_action :require_two_factor!, only: %i[show setup confirm]

        # Confirming and regenerating need a code; cap guessing per IP.
        rate_limit to: Rails.configuration.x.two_factor_rate_limit_per_ip, within: 1.minute, name: "two-factor-ip",
                   store: Rails.configuration.x.api_rate_limit_store || Rails.cache, only: %i[confirm recovery_codes],
                   with: -> { render_error(:too_many_requests, "rate_limited", "Too many attempts. Wait a minute and try again.") }

        def show
          user = Current.user
          render json: { data: { enabled: user.two_factor_enabled?, enabledAt: user.otp_enabled_at&.iso8601,
                                 remainingRecoveryCodes: user.two_factor_enabled? ? user.remaining_recovery_codes : nil } }
        end

        def setup
          return render_error(:conflict, "already_enabled", "Two-factor login is already on.") if Current.user.two_factor_enabled?

          setup = Current.user.start_two_factor_setup!
          audit!("admin.two_factor_setup_started", subject: Current.user)
          # An SVG image as a data: URI, so the client shows it with <img> (an <img> can't run scripts).
          svg = RQRCode::QRCode.new(setup[:uri]).as_svg(module_size: 4, standalone: true, use_path: true)
          render json: { data: { secret: setup[:secret], otpauthUri: setup[:uri], qrCodeDataUri: "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}" } }
        end

        def confirm
          return render_error(:conflict, "already_enabled", "Two-factor login is already on.") if Current.user.two_factor_enabled?

          codes = Current.user.confirm_two_factor!(params[:code].to_s.strip)
          return render_error(:unprocessable_content, "invalid_code", "That code didn't match. Check the time on your phone and try again.") unless codes

          # Any other session was created with the password alone (possibly by someone else): end them.
          Current.user.sessions.where.not(id: Current.session.id).update_all(revoked_at: Time.current)
          audit!("admin.two_factor_enabled", subject: Current.user)
          render json: { data: { recoveryCodes: codes } }
        end

        def recovery_codes
          unless Current.user.verify_two_factor_code!(params[:code].to_s.strip)
            return render_error(:unprocessable_content, "invalid_code", "That code didn't match.")
          end

          codes = Current.user.regenerate_recovery_codes!
          audit!("admin.recovery_codes_regenerated", subject: Current.user)
          render json: { data: { recoveryCodes: codes } }
        end
      end
    end
  end
end
