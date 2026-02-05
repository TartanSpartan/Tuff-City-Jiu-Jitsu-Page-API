# Conditional Skylight startup.
# Skylight will auto-start if config/skylight.yml contains an `authentication` token
# or if the environment variable SKYLIGHT_AUTHENTICATION is present. This initializer
# ensures Skylight doesn't attempt to run in test environments or without a token.

if defined?(Skylight)
  begin
    token = ENV["SKYLIGHT_AUTHENTICATION"]
    config_file = Rails.root.join("config", "skylight.yml")
    if token.present? || config_file.exist?
      Skylight.start! unless Rails.env.test?
    end
  rescue => e
    Rails.logger.warn("Skylight initialization skipped: ")
    Rails.logger.warn(e.message)
  end
end
