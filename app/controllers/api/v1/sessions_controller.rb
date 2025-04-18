module Api
    module V1
      class SessionsController < Api::ApplicationController
        respond_to :json

        def new
            if params[:error] == "omniauth_failure"
              response.headers["Content-Type"] = "application/json; charset=utf-8" # Explicitly set content type
              render json: { error: "Omniauth Failure", reason: params[:reason] }, status: :unauthorized
            else
              render json: { message: "Please sign in." }, status: :ok
            end
        end

            def create
                if params[:email].blank?
                    render json: { error: "Invalid email or password" }, status: :unauthorized
                    return
                end

                if params[:password].blank?
                    render json: { error: "Invalid email or password" }, status: :unauthorized
                    return
                end

                user = User.find_by(email: params[:email].strip.downcase)

                if user.nil?
                    render json: { error: "Email not found" }, status: :not_found
                else
                    if user.valid_password?(params[:password].strip) # Use valid_password? to check password
                    sign_in(user) # Use Devise to sign the user in
                    render(json: { status: 200, logged_in: true, user: { id: user.id, email: user.email, first_name: user.first_name, last_name: user.last_name } }, status: :ok)
                    else
                    render(json: { error: "Invalid email or password" }, status: :unauthorized)
                    end
                end
            end

            def destroy
                if current_api_v1_user
                    sign_out(current_api_v1_user)
                    reset_session
                    cookies.each do |key, value|
                        cookies.delete(key, domain: "www.example.com", path: "/") if key != "CSRF-TOKEN"
                    end
                    head :no_content
                else
                    # User was not logged in
                    render json: { error: "No active session found." }, status: :unauthorized 
                end
            end
        end
    end
end