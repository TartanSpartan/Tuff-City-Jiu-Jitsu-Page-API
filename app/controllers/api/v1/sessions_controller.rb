module Api
  module V1
    class SessionsController < Api::ApplicationController
      # TODO: In a commit not too long from now we need to transition the API to use token-based authentication instead of session/cookie-based.
      # This will involve significant changes to how sessions are handled here.
      # For now, we maintain session-based auth for compatibility with the existing frontend.

      def new
        # TODO: Confirm whether this route is being used by the frontend at all.
        # If the user is already logged in, we might want to return their info instead.
        if params[:error] == "omniauth_failure"
          response.headers["Content-Type"] = "application/json; charset=utf-8" # Explicitly set content type
          render json: {
                   error: "Omniauth Failure",
                   reason: params[:reason]
                 },
                 status: :unauthorized
        else
          render json: { message: "Please sign in." }, status: :ok
        end
      end

      def create
        begin
          # 1. Use session_params to access the nested keys from the frontend request
          email = session_params[:email]&.strip&.downcase
          password = session_params[:password]&.strip

          if Rails.env.development?
            Rails.logger.info("--- SESSIONS CREATE DEBUG START ---")
          end
          if Rails.env.development?
            Rails.logger.info(
              "Received email: #{email.present? ? email : "BLANK"}"
            )
          end
          if Rails.env.development?
            Rails.logger.info(
              "Received password: #{password.present? ? "PRESENT" : "BLANK"}"
            )
          end

          # 2. Check for missing credentials early
          if email.blank? || password.blank?
            if Rails.env.development?
              Rails.logger.info(
                "DEBUG: Authentication failed early - Missing credentials."
              )
            end
            render json: {
                     error: "Invalid email or password"
                   },
                   status: :unauthorized
            return
          end

          user = User.find_by(email: email)

          if user.nil?
            if Rails.env.development?
              Rails.logger.info("DEBUG: User not found for email: #{email}")
            end
            # Best practice is to return a generic "Invalid email or password" for security
            render json: {
                     error: "Invalid email or password"
                   },
                   status: :unauthorized
          else
            if Rails.env.development?
              Rails.logger.info(
                "DEBUG: User found (ID: #{user.id}, Email: #{user.email})"
              )
            end
            # 3. Use Devise's `valid_password?` (already correct)
            if user.valid_password?(password)
              if Rails.env.development?
                Rails.logger.info(
                  "DEBUG: Password validation successful for User ID: #{user.id}"
                )
              end

              # Successful authentication
              sign_in(user) # Sign the user in (handles session/cookie)

              # Return the user data
              if Rails.env.development?
                Rails.logger.info(
                  "DEBUG: Attempting successful JSON render and return for User ID: #{user.id}"
                )
              end
              render(
                json: {
                  status: 200,
                  logged_in: true,
                  user: {
                    id: user.id,
                    email: user.email,
                    first_name: user.first_name,
                    last_name: user.last_name
                  }
                },
                status: :ok
              ) and return
            else
              if Rails.env.development?
                Rails.logger.info(
                  "DEBUG: Password validation FAILED for User ID: #{user.id}"
                )
              end
              # Failed password check
              render(
                json: {
                  error: "Invalid email or password"
                },
                status: :unauthorized
              )
            end
          end
        rescue => e
          # If a crash occurs, log the stack trace and send a 500
          Rails.logger.error "FATAL SESSION ERROR: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: {
                   error: "An unexpected server error occurred during sign in."
                 },
                 status: :internal_server_error
        ensure
          if Rails.env.development?
            Rails.logger.info("--- SESSIONS CREATE DEBUG END ---")
          end
        end
      end

      def destroy
        if current_api_v1_user
          sign_out(current_api_v1_user)
          # Note: `reset_session` clears all session data, which may be aggressive
          # if we have other session data, but is usually safe for logout.
          reset_session

          head :no_content
        else
          # User was not logged in
          render json: {
                   error: "No active session found."
                 },
                 status: :unauthorized
        end
      end

      private

      # Strong parameters to permit the nested email and password attributes
      def session_params
        params.require(:session).permit(:email, :password)
      rescue ActionController::ParameterMissing
        # Handle cases where the :session key is missing entirely, returning empty hash
        {}
      end
    end
  end
end
