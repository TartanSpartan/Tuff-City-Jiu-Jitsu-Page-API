# app/serializers/user_serializer.rb (JSONAPI::Serializer variant)
class UserSerializer
  include JSONAPI::Serializer
  set_type :users
  attributes :first_name, :last_name, :email, :is_admin,
             :owns_gi, :has_first_aid_qualification, :first_aid_achievement_date,
             :effective_kyu_grade

  has_one :current_belt_grade, serializer: BeltGradeSerializer
  has_one :current_instructor_qualification, serializer: InstructorQualificationSerializer
end

Then in controller:

render json: UserSerializer.new(user, include: [
  :current_belt_grade,
  :'current_belt_grade.belt',
  :current_instructor_qualification
]).serializable_hash

## Example Payload (plain JSON)
{
  "user": {
    "id": 2,
    "first_name": "David",
    "last_name": "Corbett",
    "email": "tuffcityjitsu@gmail.com",
    "is_admin": true,
    "owns_gi": true,
    "has_first_aid_qualification": false,
    "first_aid_achievement_date": null,
    "effective_kyu_grade": 5,
    "current_belt_grade": {
      "id": 101,
      "belt_id": 5,
      "grade_name": "Green",
      "obtained_at": "2024-03-10",
      "effective_kyu_grade": 5,
      "belt": { "id": 5, "name": "Green", "colour": "green", "kyu_number": 5 }
    },
    "current_instructor_qualification": {
      "qualification_id": 2,
      "achieved_at": "2025-06-01"
    }
  }
}

## Verification
- Rails Console
u = User.find(2)
u.current_belt_grade&.obtained_at
u.current_belt_grade&.belt&.kyu_number
u.effective_kyu_grade
u.current_instructor_qualification&.qualification_id
u.current_instructor_qualification&.achieved_at

- Curl (show)
curl -s http://localhost:3000/api/v1/users/2 | jq

- Curl (index)
curl -s http://localhost:3000/api/v1/users | jq

## Notes
- Ensure obtained_at is present for the latest belt grade; the client pre-fills the date picker with it.
- If you cannot or do not wish to include nested belt, ensure effective_kyu_grade is provided so the client can render the coloured pill reliably.
- Keep grade_name values normalized (e.g., "Light Blue", "Dark Blue"). The client has a fallback mapper but kyu_number is preferred.