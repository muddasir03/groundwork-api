module Api
  module V1
    module Admin
      # Every admin endpoint inherits from this. Requests must carry a valid, unexpired, unrevoked
      # session token for an admin, in the Authorization header only (never in the URL, where it
      # would end up in logs and browser history). See docs/SECURITY.md.
      class BaseController < Api::V1::BaseController
        before_action :authenticate!
        before_action :require_admin!
        after_action :no_store

        private

        def authenticate!
          session = ::Session.find_active(bearer_token)
          return render_error(:unauthorized, "unauthorized", "Log in to continue.") unless session

          session.touch_last_used!
          Current.session = session
        end

        # A logged-in non-admin gets 403, not 401: they're authenticated, just not allowed.
        def require_admin!
          return if performed? || Current.user&.admin?

          render_error(:forbidden, "forbidden", "You don't have access to this.")
        end

        def bearer_token
          request.authorization.to_s[/\ABearer ([A-Za-z0-9_\-]{1,100})\z/, 1]
        end

        # Admin responses contain unpublished research; no browser or proxy may cache them.
        def no_store
          response.headers["Cache-Control"] = "no-store"
        end

        def audit!(action, subject: nil, **details)
          AuditEvent.record!(action, user: Current.user, subject: subject, ip_address: request.remote_ip, **details)
        end
      end
    end
  end
end
