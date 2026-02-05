Rails.application.config.session_store :cookie_store,
  key: "_tuff_city_jiu_jitsu_api_tablet_session",
  secure: Rails.env.production?,
  same_site: (Rails.env.production? ? :none : :lax),
  httponly: true

# Keep session_options in sync for any lower-level code that reads them.
Rails.application.config.session_options = {
  secure: Rails.application.config.session_options[:secure] || Rails.env.production?,
  same_site: (Rails.env.production? ? :none : :lax),
  httponly: true
}
