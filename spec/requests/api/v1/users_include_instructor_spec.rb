# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users includes (instructor qualification)", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:white_belt) { create(:belt, colour: "White") }
  let!(:belt_grade) do
    create(:belt_grade, user: user, belt: white_belt, obtained_at: Date.current)
  end

  let!(:no_qual) do
    create(:qualification, level: "No qualifications", belt: white_belt)
  end
  let!(:iq) do
    create(
      :instructor_qualification,
      user: user,
      belt: white_belt,
      belt_grade: belt_grade,
      qualification: no_qual,
      achieved_at: Date.current
    )
  end

  it "returns current_instructor_qualification in JSON:API included when requested" do
    sign_in admin_user

    get "/api/v1/users/#{user.id}",
        params: {
          include: "current_instructor_qualification"
        }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    # Print the full payload and nested included instructor qualification for inspection
    puts "\n[DEBUG] Users includes (instructor) - Full payload:" \
           "\n" + JSON.pretty_generate(payload)
    expect(payload["data"]["id"]).to eq(user.id.to_s)
    expect(payload["data"]["type"]).to eq("users")

    included = payload["included"]
    expect(included).to be_an(Array)
    puts "\n[DEBUG] Users includes (instructor) - Included resources:" \
           "\n" + JSON.pretty_generate(included)

    included_iq =
      included.find { |res| res["type"] == "instructor_qualifications" }
    expect(included_iq).to be_present

    # Validate key fields
    expect(included_iq["attributes"]["qualification_id"]).to eq(
      iq.qualification_id
    )
    expect(Date.parse(included_iq["attributes"]["achieved_at"]).to_date).to eq(
      iq.achieved_at.to_date
    )
  end
end
