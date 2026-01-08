# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users minimal serialization", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:yellow_belt) { create(:belt, colour: "Yellow") }
  let!(:belt_grade) do
    create(
      :belt_grade,
      user: user,
      belt: yellow_belt,
      obtained_at: Date.current
    )
  end

  it "returns minimal JSON with effective_kyu_grade when include is not provided" do
    sign_in admin_user

    get "/api/v1/users/#{user.id}"

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    # Print the minimal payload for quick inspection
    puts "\n[DEBUG] Users minimal - Full payload:" \
           "\n" + JSON.pretty_generate(payload)

    expect(payload["id"]).to eq(user.id)
    expect(payload["first_name"]).to eq(user.first_name)
    expect(payload["email"]).to eq(user.email)

    # Prove effective_kyu_grade provided for client rendering
    expect(payload["effective_kyu_grade"]).to eq(belt_grade.effective_kyu_grade)

    # Ensure no JSON:API structure
    expect(payload).to_not have_key("data")
    expect(payload).to_not have_key("included")
  end
end
