module Api
  module V1
    # Shared behaviour for every v1 endpoint: one error format, rate limiting, and safe defaults.
    # Errors look like: { "error": { "code": "not_found", "message": "Company not found" } }
    class BaseController < ApplicationController
      # Per-IP limit. Requests over it get a 429 with a JSON error instead of reaching the database.
      rate_limit to: Rails.configuration.x.api_rate_limit,
                 within: 1.minute,
                 store: Rails.configuration.x.api_rate_limit_store || Rails.cache,
                 with: -> { render_error(:too_many_requests, "rate_limited", "Too many requests. Try again in a minute.") }

      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, "not_found", "Not found")
      end

      rescue_from ActionController::ParameterMissing do |error|
        render_error(:unprocessable_content, "parameter_missing", error.message)
      end

      private

      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end

      # Page-based pagination with a hard cap, so a single request can't pull the whole table.
      def pagination(default_per_page: 20, max_per_page: 50)
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].presence ? params[:per_page].to_i.clamp(1, max_per_page) : default_per_page
        { page: page, per_page: per_page, offset: (page - 1) * per_page }
      end
    end
  end
end
