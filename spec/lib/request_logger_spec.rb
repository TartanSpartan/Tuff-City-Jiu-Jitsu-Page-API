require "rails_helper"

RSpec.describe RequestLogger do
  let(:app) do
    # Minimal Rack app returning 200 OK
    ->(env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
  end

  let(:middleware) { described_class.new(app) }

  let(:env) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/test",
      "rack.request.form_hash" => {
        "q" => "search"
      },
      "SCRIPT_NAME" => "",
      "rack.mount_point" => "/",
      "rack.route_info" => {
      },
      # Simulated HTTP headers that should be logged
      "HTTP_USER_AGENT" => "RSpec",
      "HTTP_ACCEPT" => "*/*"
    }
  end

  it "logs start/end markers and basic request details" do
    allow(Rails.logger).to receive(:debug)

    status, headers, body = middleware.call(env)

    expect(status).to eq(200)
    expect(headers["Content-Type"]).to eq("text/plain")
    expect(body.join).to eq("OK")

    expect(Rails.logger).to have_received(:debug).with(
      "--- RequestLogger Middleware Processing ---"
    )
    expect(Rails.logger).to have_received(:debug).with(/Request Method: GET/)
    expect(Rails.logger).to have_received(:debug).with(%r{Request Path: /test})
    expect(Rails.logger).to have_received(:debug).with(
      /--- End RequestLogger Middleware ---/
    )
  end
end
