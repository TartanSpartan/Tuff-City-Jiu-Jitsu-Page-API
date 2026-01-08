require "rails_helper"

RSpec.describe "Syllabi secondary endpoints", type: :request do
  describe "GET /api/v1/syllabi/get_secondary" do
    it "returns the secondary syllabus when present" do
      # Arrange: two syllabi, mark one as secondary
      s1 = create(:syllabus, country: "UK", year: 2024)
      s2 = create(:syllabus, country: "Canada", year: 2024)
      s2.update!(is_secondary_admin_syllabus: true)

      # Act
      get "/api/v1/syllabi/get_secondary"

      # Assert
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      # JSON:API structure
      expect(json["data"]).to be_present
      expect(json["data"]["id"]).to eq(s2.id.to_s)
      attrs = json["data"]["attributes"]
      expect(attrs["country"]).to eq("Canada")
      expect(attrs["year"]).to eq(2024)
    end

    it "returns 404 when no secondary syllabus is set" do
      # Arrange: no syllabus flagged secondary
      create(:syllabus, country: "UK", year: 2024)

      # Act
      get "/api/v1/syllabi/get_secondary"

      # Assert
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Secondary syllabus not found.")
    end
  end

  describe "PUT /api/v1/syllabi/set_secondary" do
    let(:admin) { create(:user, :admin) }

    it "sets the secondary syllabus when called by an admin" do
      # Arrange
      sign_in admin
      s1 = create(:syllabus, country: "UK", year: 2024)
      s2 = create(:syllabus, country: "Canada", year: 2024)

      # Act
      put "/api/v1/syllabi/set_secondary", params: { syllabus_id: s2.id }

      # Assert
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("success")

      # Reload and check flags
      expect(Syllabus.find(s1.id).is_secondary_admin_syllabus).to be_falsey
      expect(Syllabus.find(s2.id).is_secondary_admin_syllabus).to be_truthy
    end

    it "returns 403 when a non-admin attempts to set secondary" do
      # Arrange
      user = create(:user) # non-admin
      sign_in user
      s1 = create(:syllabus, country: "UK", year: 2024)

      # Act
      put "/api/v1/syllabi/set_secondary", params: { syllabus_id: s1.id }

      # Assert
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end
  end
end
