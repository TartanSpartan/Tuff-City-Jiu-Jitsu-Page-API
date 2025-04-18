# Rails.logger.debug "--- OmniAuth Initializer Loaded ---"

Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_id_token,
             aud_claim: Rails.application.credentials.dig(:API, :google_client_id),
             azp_claim: Rails.application.credentials.dig(:API, :google_client_id)
  end

# Rails.application.config.middleware.use OmniAuth::Builder do
# Rails.application.config.middleware.insert_before Warden::Manager, OmniAuth::Builder do
#     provider :google_oauth2, Rails.application.credentials.dig(:API, :google_client_id), Rails.application.credentials.dig(:API, :google_client_secret), {
#         scope: 'email profile',
#         include_granted_scopes: true,
#         prompt: 'select_account',
#         callback_path: '/api/v1/users/auth/google_oauth2/callback',
#         provider_ignores_state: true,
#         client_options: {
#             additional_parameters: { "access_type" => "offline" }
#         }
#     }

#     OmniAuth.config.allowed_request_methods = [:post, :get]
#     # OmniAuth.config.allowed_request_methods = [:post]
# end