module Api::V1
  class CsrfTokensController < Api::ApplicationController
    def index
      # Issues a CSRF authenticity token for clients (e.g., SPA) to include with
      # subsequent state-changing requests. This endpoint is typically public
      # and respects the current Rails CSRF configuration.
      if Rails.env.development?
        Rails.logger.debug(
          "CSRF token issued: origin=#{request.origin} base_url=#{request.base_url}"
        )
      end
      render json: { csrf_token: form_authenticity_token }
    end
  end
end
