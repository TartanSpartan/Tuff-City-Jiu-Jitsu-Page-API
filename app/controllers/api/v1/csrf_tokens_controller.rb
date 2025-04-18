module Api::V1
  class CsrfTokensController < Api::ApplicationController
    def index
        # Rails.logger.debug "Request Base URL (from csrf tokens controller): #{request.base_url}"
        # Rails.logger.debug "Request Origin (from csrf tokens controller): #{request.origin}"
      render json: { csrf_token: form_authenticity_token }
    end
  end
end