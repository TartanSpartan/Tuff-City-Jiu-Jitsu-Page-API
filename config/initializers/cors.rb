# # Be sure to restart your server when you modify this file.

# # Avoid CORS issues when API is called from the frontend app.
# # Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# # Read more: https://github.com/cyu/rack-cors

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   # allow do
#   #   origins '*'
#   #   resource '*',
#   #     headers: :any,
#   #     methods: [:get, :post, :put, :patch, :delete, :options, :head],
#   #     credentials: true
#   # end

#   allow do
#     origins Rails.application.credentials.dig(:API, :host_alpha_client)
#     resource "*",
#              headers: :any,
#              methods: %i[get post put patch delete options head],
#              credentials: true,
#              expose_headers: ["X-CSRF-Token"]
#   end

#   # In case of serving client from tablet code base
#   allow do
#     origins "http://localhost:5500",
#             "http://127.0.0.1:5500",
#             "http://192.168.1.42:5500" # add IPs you use

#     resource "*",
#              headers: :any,
#              methods: %i[get post put patch delete options head],
#              credentials: true,
#              expose: ["X-CSRF-Token"]
#   end
# end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins [
              Rails.application.credentials.dig(:API, :host_alpha_client), # must be like "http://host:5500"
              "http://localhost:5500",
              "http://127.0.0.1:5500",
              "http://192.168.1.42:5500"
            ].compact # compact removes nils if the credential is missing

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             expose: ["X-CSRF-Token"]
  end
end
