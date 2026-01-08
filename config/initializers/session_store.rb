Rails.application.config.session_store :cookie_store, key: "_tuff_city_jiu_jitsu_api_tablet_session"

# 2. We explicitly configure the cookie security attributes required for cross-origin requests.
# These settings tell the browser to safely send the cookie in cross-site requests.
Rails.application.config.session_options = {
  # Forces the browser to only send the cookie over HTTPS. CRITICAL for production/Tailscale.
  # If you are testing locally without HTTPS, you may need to temporarily set this to false.
  secure: Rails.env.production? || true,

  # Sets the SameSite attribute to 'None'. This allows the cookie to be sent
  # with cross-site requests. This MUST be combined with `secure: true`.
  same_site: :none,

  # Ensures the cookie is only accessible via HTTP requests, not JavaScript.
  httponly: true

  # Sets the domain if needed, but leaving it nil usually works best for flexible deployments.
  # domain: :all
}
