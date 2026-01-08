# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users includes", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:green_belt) { create(:belt, colour: "Green") }
  let!(:belt_grade) do
    create(:belt_grade, user: user, belt: green_belt, obtained_at: Date.current)
  end

  it "returns current_belt_grade and nested belt in JSON:API included when requested" do
    sign_in admin_user

    get "/api/v1/users/#{user.id}",
        params: {
          include: "current_belt_grade.belt"
        }

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    # Print the full payload and specifically the nested included resources for inspection
    puts "\n[DEBUG] Users includes (admin) - Full payload:" \
           "\n" + JSON.pretty_generate(payload)
    # Top-level data
    expect(payload["data"]["id"]).to eq(user.id.to_s)
    expect(payload["data"]["type"]).to eq("users")

    # Included resources should contain the belt_grade and the belt
    included = payload["included"]
    expect(included).to be_an(Array)
    puts "\n[DEBUG] Users includes (admin) - Included resources:" \
           "\n" + JSON.pretty_generate(included)

    # Find belt_grade and belt entries
    included_bg = included.find { |res| res["type"] == "belt_grades" }
    included_belt = included.find { |res| res["type"] == "belts" }

    expect(included_bg).to be_present
    expect(included_belt).to be_present

    expect(included_bg["id"]).to eq(belt_grade.id.to_s)
    expect(included_bg["attributes"]["effective_kyu_grade"]).to eq(
      belt_grade.effective_kyu_grade
    )
    expect(included_bg["attributes"]["grade_name"]).to eq(belt_grade.grade_name)

    expect(included_belt["id"]).to eq(green_belt.id.to_s)
    expect(included_belt["attributes"]["kyu_number"]).to eq(
      green_belt.kyu_number
    )
    expect(included_belt["attributes"]["colour"]).to eq(green_belt.colour)
  end
end
