# class Api::ApplicationController < ApplicationController
# end

# Note: Don't need a Base Action Controller for a lightweight API serving JSON data. Can go back to that if we ever want views, flash messages etc to be shown via a more Rails-centric frontend.
# class Api::ApplicationController < ActionController::Base
module Api
    class ApplicationController < ActionController::Base
    # class ApplicationController < ::ApplicationController
        before_action :set_csrf_cookie
        include ActionController::Cookies
        include ActionController::Helpers
        include ActionController::RequestForgeryProtection 
        include Devise::Controllers::Helpers
        # include Devise::Helpers
        respond_to :json

        Rails.logger.info "ApplicationController: Hello from ApplicationController!"

        protect_from_forgery with: :exception

        rescue_from StandardError, with: :standard_error
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
        # Now that we have those here, do we need them anywhere else?

        # To send a json error message when a user types in, for example: localhost:3000/api/v1/wrongthing
        def not_found
            render(
                json: {
                errors: [{
                    type: "Not Found"
                }]
                },
                status: :not_found #alias for 404 in rails
            )
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
                    json: { status: 401, error: "User must be logged in to access this resource" },
                    status: :unauthorized
                )
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
        
        
        def record_invalid(error)
            # Our object should look something like this:
            # {
            #   errors: [
            #     {
            #       type: "ActiveRecord::RecordInvalid",
            #       record_typeL "Question",
            #       field: "body",
            #       message: '...'
            #     }
            #   ]
            # }
            invalid_record = error.record
            errors = invalid_record.errors.map do |field, message|
            {
                type: error.class.to_s, # need it in string format
                record_type: invalid_record.class.to_s,
                field: field,
                message: message
            }
            end
            render(
            json: {status: 422, errors: errors },
            status: :unprocessable_entity
            )
        end
        
        def record_not_found(error)
            render(
            status: 404,
            json: {
                status: 404,
                errors: [{
                type: error.class.to_s,
                message: error.message
                }]
                }
            )
        end
        
        def standard_error(error)
            # When we rescue an error, we prevent our program from
            # doing what it would normally do in a crash, such as logging
            # the details and the backtrace.  It's important to always log this
            # information when rescuing a general type
        
            # Use the logger.error method with an error's message to 
            # log the error details again
        
            # # logger.error error.full_message
            # logger.error "#{error.class}: #{error.message}"
            # logger.error error.backtrace.join("\n") if error.backtrace

            logger.error({
                error_type: error.class.to_s,
                message: error.message,
                backtrace: error.backtrace&.first(10)
            }.to_json)

            render(
                status:500,
                json:{
                status:500, #alias :internal_server_error
                errors:[{
                    type: error.class.to_s,
                    message: error.message
                }]
                }
            )
        end
    end
end