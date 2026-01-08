# Note: Don't need a Base Action Controller for a lightweight API serving JSON data. Can go back to that if we ever want views, flash messages etc to be shown via a more Rails-centric frontend. But that's quite unlikely given our solid React frontend.
module Api
  class ApplicationController < ActionController::API
    # class ApplicationController < ::ApplicationController

    # TODO: Consider whether CSRF protection is needed for API endpoints.
    # If needed, uncomment the line below and ensure proper CSRF token handling on the client side.
    # skip_before_action :verify_authenticity_token

    before_action :set_csrf_cookie
    include ActionController::Cookies
    include ActionController::Helpers
    include ActionController::RequestForgeryProtection
    include Devise::Controllers::Helpers
    # respond_to :json

    Rails.logger.info "ApplicationController: Hello from ApplicationController!"

    # protect_from_forgery with: :exception

    rescue_from StandardError, with: :standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

    # To send a JSON error message when a user types an unknown route
    # Aligns with standardized error shape used across controllers
    def not_found
      render_error_response(:not_found, msg: "Not Found")
    end

    helper_method(:current_user)

    helper_method(:current_api_v1_user)

    private

    def current_api_v1_user
      @current_api_v1_user ||= warden.authenticate(scope: :api_v1_user)
    end

    def authenticate_api_v1_user!
      unless current_api_v1_user.present?
        render(
          json: {
            status: 401,
            error: "User must be logged in to access this resource"
          },
          status: :unauthorized
        ) and return
      end
    end

    def authorize_admin!
      unless current_api_v1_user&.is_admin?
        render json: { error: "Forbidden" }, status: :forbidden and return
      end
    end

    def set_csrf_cookie
      cookies["CSRF-TOKEN"] = {
        value: form_authenticity_token,
        domain: Rails.application.credentials.dig(:API, :domain)
      }
    end

    protected

    # protected is like a private except that it prevents
    # descendent classes from using protected methods

    # 422 - Unprocessable Entity (validation errors)
    # Standardized to a flat list of error messages
    def record_invalid(error)
      messages = error.record.errors.full_messages
      render_error_response(:unprocessable_entity, errors: messages)
    end

    # 404 - Not Found
    # Standardized to { status: 404, errors: { msg: "Record Not Found" } }
    def record_not_found(_error)
      render_error_response(:not_found, msg: "Record Not Found")
    end

    # 500 - Internal Server Error
    # Standardized to { status: 500, errors: { msg: "Internal Server Error: <message>" } }
    def standard_error(error)
      # Prevent double render if a response has already been sent
      return if performed?

      # Log error details
      logger.error(
        {
          error_type: error.class.to_s,
          message: error.message,
          backtrace: error.backtrace&.first(10)
        }.to_json
      )

      render_error_response(
        :internal_server_error,
        msg: "Internal Server Error: #{error.message}"
      )
    end

    # Centralized helper for standardized error payloads across controllers.
    # Usage:
    #   render_error_response(:not_found, msg: "Record Not Found")
    #   render_error_response(:unprocessable_entity, errors: model.errors.full_messages)
    # If `msg` is provided, shape is { status: N, errors: { msg: "..." } }
    # If `errors` (Array) is provided, shape is { status: N, errors: ["...", "..."] }
    # Note: prefer one of msg or errors for clear shape.
    def render_error_response(status_symbol, msg: nil, errors: nil)
      status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status_symbol]
      payload = { status: status_code }
      if msg
        payload[:errors] = { msg: msg }
      elsif errors
        payload[:errors] = errors
      else
        payload[:errors] = {
          msg: Rack::Utils::HTTP_STATUS_CODES[status_code] || "Error"
        }
      end
      render json: payload, status: status_symbol
    end
  end
end
