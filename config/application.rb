require_relative '../lib/request_logger'
require_relative "boot"

# require "rails/all"
# require "action_controller/metal/request_forgery_protection"
# require "abstract_controller/helpers" 
# require "abstract_controller"

# require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
# require "actionpack/railtie"
# require "action_controller/railtie"
# require "action_mailer/railtie"
# # require "action_mailbox/engine"
# # require "action_text/engine"
# require "action_view/railtie"
# require "action_cable/engine"
# # require "rails/test_unit/railtie"

# require "action_controller/base"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"




# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TuffCityJiuJitsuApiTablet
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
#     config.api_only = true

#     config.middleware.use ActionDispatch::Cookies # Required for all session management
#     config.middleware.use ActionDispatch::Session::CookieStore
#     # config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore # Force session before Warden
    
#     # Rails.application.config.middleware.insert_before Warden::Manager, OmniAuth::Builder do
#     # config.middleware.use OmniAuth::Builder do
#     # config.middleware.insert_before Warden::Manager, OmniAuth::Builder do
#     # config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore do |builder|
#     config.middleware.insert_before Warden::Manager, OmniAuth::Builder do |builder|
#       builder.provider :google_oauth2, Rails.application.credentials.dig(:API, :google_client_id), Rails.application.credentials.dig(:API, :google_client_secret), {
#           scope: 'email profile',
#           include_granted_scopes: true,
#           prompt: 'select_account',
#           callback_path: '/api/v1/users/auth/google_oauth2/callback',
#           provider_ignores_state: true,
#           client_options: {
#               additional_parameters: { "access_type" => "offline" }
#           }
#       }
  
#       OmniAuth.config.allowed_request_methods = [:post, :get]
#       # OmniAuth.config.allowed_request_methods = [:post]
#   end    

#   config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore # Force session before Warden (This line might be redundant now, but let's keep it for extra assurance)

#     # , config.session_options
#     # config.middleware.use ActionDispatch::RequestForgeryProtection
#     config.action_controller.forgery_protection_origin_check =  Rails.application.credentials.dig(:Client, :frontend_url_no_suffix)
#     # config.action_controller.forgery_protection_origin_check = :allow_any
#     # config.action_controller.forgery_protection_origin_check = false
#   end
# end

# config.api_only = true

config.autoload_paths << Rails.root.join('lib')

config.middleware.insert_after ActionDispatch::Cookies, RequestLogger

config.middleware.use ActionDispatch::Cookies # Required for all session management
config.middleware.use ActionDispatch::Session::CookieStore
# config.middleware.use Warden::Manager

config.middleware.insert_before Warden::Manager, OmniAuth::Builder do |builder|
  builder.provider :google_oauth2, Rails.application.credentials.dig(:API, :google_client_id), Rails.application.credentials.dig(:API, :google_client_secret), {
      scope: 'email profile',
      include_granted_scopes: true,
      prompt: 'select_account',
      callback_path: '/api/v1/auth/google_oauth2/callback',
      provider_ignores_state: true,
      client_options: {
          additional_parameters: { "access_type" => "offline" }
      }
  }

  OmniAuth.config.allowed_request_methods = [:post, :get]
end

config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

config.action_controller.forgery_protection_origin_check =  Rails.application.credentials.dig(:Client, :frontend_url_no_suffix)
end
end