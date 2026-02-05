# Skylight Setup (Development)

This project includes a Skylight scaffold to collect server-side performance traces.

- The `skylight` gem is present in both the `:development` and `:production` groups in the `Gemfile`.
- Provide your Skylight authentication token via the `SKYLIGHT_AUTHENTICATION` environment variable, or copy `config/skylight.yml.example` to `config/skylight.yml` and set `authentication: "..."`.

Quick local steps:

```bash
export SKYLIGHT_AUTHENTICATION=your_token_here
bundle install --with development
bin/rails server
```

Notes:
- The initializer `config/initializers/skylight.rb` starts Skylight only when a token or config file exists and will skip startup in the `test` environment.
- Skylight records server-side traces for API-only JSON responses; you can view traces in the Skylight web UI.
- If you prefer New Relic or Datadog, I can add scaffold instructions for those.
