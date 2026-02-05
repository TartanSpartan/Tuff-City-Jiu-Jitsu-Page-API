# Configure Oj for Rails JSON encoding/decoding performance
begin
  require 'oj'

  # Optimize Rails integration (overrides to_json, encode, etc.)
  Oj.optimize_rails

  # Set a safe default mode; :compat makes Oj behave like the stdlib JSON
  # while still being faster. Adjust as needed for your app.
  Oj.default_options = {
    mode: :compat,
    time_format: :ruby,
    use_to_json: true,
    use_to_hash: true
  }
rescue LoadError
  Rails.logger.warn "Oj gem not available; falling back to stdlib JSON"
end
