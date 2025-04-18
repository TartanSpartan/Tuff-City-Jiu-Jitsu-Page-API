module Api
    module V1
      module Users
         class OmniauthCallbacksController < Devise::OmniauthCallbacksController
            respond_to :json
            skip_before_action :verify_authenticity_token, only: :google_oauth2

            def passthru
                # Consider if it's worth adding logic to check for a google_id_token in the parameters of a POST request, for now, this method will suffice as it is
                request.env['omniauth.strategy'] = :google_oauth2
                super
            end

            def google_oauth2
                # request.env.each { |k, v| Rails.logger.debug "  #{k}: #{v.inspect}" }

                if params[:error].present?
                    reason = params['error_description'] || params['error']
                    redirect_to new_api_v1_user_session_path(format: :json, error: 'omniauth_failure', reason: reason), status: :found
                else
                    auth_hash = request.env['omniauth.auth']
                    id_token = auth_hash&.dig('extra', 'id_token')
                    @user = User.from_omniauth(request.env['omniauth.auth'])
            
                    if @user.present? && @user.persisted?
                        sign_in @user, scope: :api_v1_user, event: :authentication
                        redirect_to Rails.application.credentials.dig(:Client, :frontend_url), allow_other_host: true
                    else
                        session["devise.google_oauth2_data"] = request.env["omniauth.auth"].except("extra") if request.env["omniauth.auth"].present?
                        render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
                    end
                end

                rescue StandardError => e
                    Rails.logger.error "OmniauthCallbacksController: google_oauth2 action ERROR: #{e.message}"
                    Rails.logger.error "OmniauthCallbacksController: Backtrace: #{e.backtrace.join("\n")}"
                    Rails.logger.debug "RESCUE BLOCK EXECUTED"
                    render json: { error: 'OAuth authentication failed' }, status: :unauthorized
                end

            def failure
                reason = params['error_description'] || params['error'] || failure_message
                redirect_to new_api_v1_user_session_path(format: :json, error: 'omniauth_failure', reason: reason), status: :unauthorized
            end

            private
                def omniauth_error_reason
                    request.env['omniauth.error.type']
                end

                def omniauth_error_strategy
                    request.env['omniauth.error.strategy']
                end
            end
        end
    end
end