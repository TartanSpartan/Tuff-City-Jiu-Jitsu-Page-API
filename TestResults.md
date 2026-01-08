Users includes

[DEBUG] Users includes (admin) - Full payload:
{
"data": {
"id": "1",
"type": "users",
"attributes": {
"first_name": "Antony",
"last_name": "Auer",
"email": "ned@green.test",
"is_admin": false,
"dues_paid": null,
"owns_gi": true,
"has_first_aid_qualification": null,
"first_aid_achievement_date": null,
"first_aid_expiry_date": null,
"created_at": "2025-12-21T00:06:14.330Z",
"updated_at": "2025-12-21T00:06:14.330Z",
"last_sign_in_at": null,
"preferred_difference_editor_mode": null,
"effective_kyu_grade": 5
},
"relationships": {
"current_belt_grade": {
"data": {
"id": "1",
"type": "belt_grades"
}
},
"current_instructor_qualification": {
"data": null
},
"belt_grades": {
"data": [
{
"id": "1",
"type": "belt_grades"
}
],
"links": {
"related": "/users/1/belt_grades"
}
},
"instructor_qualifications": {
"data": [],
"links": {
"related": "/users/1/instructor_qualifications"
}
},
"syllabi": {
"data": [],
"links": {
"related": "/users/1/syllabi"
}
}
}
},
"included": [
{
"id": "1",
"type": "belt_grades",
"attributes": {
"user_id": 1,
"belt_id": 1,
"obtained_at": "2025-12-21",
"effective_kyu_grade": 5,
"grade_name": "Green",
"time_held": "Less than a month",
"created_at": "2025-12-21T00:06:14.370Z",
"updated_at": "2025-12-21T00:06:14.370Z"
},
"relationships": {
"user": {
"data": {
"id": "1",
"type": "users"
}
},
"belt": {
"data": {
"id": "1",
"type": "belts"
}
}
}
},
{
"id": "1",
"type": "belts",
"attributes": {
"colour": "Green",
"kyu_number": 5,
"effective_kyu_grade": 5,
"created_at": "2025-12-21T00:06:13.768Z",
"updated_at": "2025-12-21T00:06:13.768Z",
"syllabus_id": 1
},
"relationships": {
"technique_types": {
"data": []
},
"techniques": {
"data": []
},
"belt_grades": {
"data": [
{
"id": "1",
"type": "belt_grades"
}
]
}
}
}
]
}

[DEBUG] Users includes (admin) - Included resources:
[
{
"id": "1",
"type": "belt_grades",
"attributes": {
"user_id": 1,
"belt_id": 1,
"obtained_at": "2025-12-21",
"effective_kyu_grade": 5,
"grade_name": "Green",
"time_held": "Less than a month",
"created_at": "2025-12-21T00:06:14.370Z",
"updated_at": "2025-12-21T00:06:14.370Z"
},
"relationships": {
"user": {
"data": {
"id": "1",
"type": "users"
}
},
"belt": {
"data": {
"id": "1",
"type": "belts"
}
}
}
},
{
"id": "1",
"type": "belts",
"attributes": {
"colour": "Green",
"kyu_number": 5,
"effective_kyu_grade": 5,
"created_at": "2025-12-21T00:06:13.768Z",
"updated_at": "2025-12-21T00:06:13.768Z",
"syllabus_id": 1
},
"relationships": {
"technique_types": {
"data": []
},
"techniques": {
"data": []
},
"belt_grades": {
"data": [
{
"id": "1",
"type": "belt_grades"
}
]
}
}
}
]
returns current_belt_grade and nested belt in JSON:API included when requested

Users includes (owner)

[DEBUG] Users includes (owner) - Full payload:
{
"data": {
"id": "3",
"type": "users",
"attributes": {
"first_name": "Malena",
"last_name": "Corkery",
"email": "rickie_toy@upton.example",
"is_admin": false,
"dues_paid": null,
"owns_gi": true,
"has_first_aid_qualification": null,
"first_aid_achievement_date": null,
"first_aid_expiry_date": null,
"created_at": "2025-12-21T00:06:15.022Z",
"updated_at": "2025-12-21T00:06:15.022Z",
"effective_kyu_grade": 5
},
"relationships": {
"current_belt_grade": {
"data": {
"id": "2",
"type": "belt_grades"
}
},
"current_instructor_qualification": {
"data": null
},
"belt_grades": {
"data": [
{
"id": "2",
"type": "belt_grades"
}
],
"links": {
"related": "/users/3/belt_grades"
}
},
"instructor_qualifications": {
"data": [],
"links": {
"related": "/users/3/instructor_qualifications"
}
},
"syllabi": {
"data": [],
"links": {
"related": "/users/3/syllabi"
}
}
}
},
"included": [
{
"id": "2",
"type": "belt_grades",
"attributes": {
"user_id": 3,
"belt_id": 2,
"obtained_at": "2025-12-21",
"effective_kyu_grade": 5,
"grade_name": "Green",
"time_held": "Less than a month",
"created_at": "2025-12-21T00:06:15.029Z",
"updated_at": "2025-12-21T00:06:15.029Z"
},
"relationships": {
"user": {
"data": {
"id": "3",
"type": "users"
}
},
"belt": {
"data": {
"id": "2",
"type": "belts"
}
}
}
},
{
"id": "2",
"type": "belts",
"attributes": {
"colour": "Green",
"kyu_number": 5,
"effective_kyu_grade": 5,
"created_at": "2025-12-21T00:06:14.997Z",
"updated_at": "2025-12-21T00:06:14.997Z",
"syllabus_id": 2
},
"relationships": {
"technique_types": {
"data": []
},
"techniques": {
"data": []
},
"belt_grades": {
"data": [
{
"id": "2",
"type": "belt_grades"
}
]
}
}
}
]
}

[DEBUG] Users includes (owner) - Included resources:
[
{
"id": "2",
"type": "belt_grades",
"attributes": {
"user_id": 3,
"belt_id": 2,
"obtained_at": "2025-12-21",
"effective_kyu_grade": 5,
"grade_name": "Green",
"time_held": "Less than a month",
"created_at": "2025-12-21T00:06:15.029Z",
"updated_at": "2025-12-21T00:06:15.029Z"
},
"relationships": {
"user": {
"data": {
"id": "3",
"type": "users"
}
},
"belt": {
"data": {
"id": "2",
"type": "belts"
}
}
}
},
{
"id": "2",
"type": "belts",
"attributes": {
"colour": "Green",
"kyu_number": 5,
"effective_kyu_grade": 5,
"created_at": "2025-12-21T00:06:14.997Z",
"updated_at": "2025-12-21T00:06:14.997Z",
"syllabus_id": 2
},
"relationships": {
"technique_types": {
"data": []
},
"techniques": {
"data": []
},
"belt_grades": {
"data": [
{
"id": "2",
"type": "belt_grades"
}
]
}
}
}
]
allows the owner to request current_belt_grade and nested belt via include param

Users includes (instructor qualification)

[DEBUG] Users includes (instructor) - Full payload:
{
"data": {
"id": "4",
"type": "users",
"attributes": {
"first_name": "Robin",
"last_name": "Ullrich",
"email": "man.wyman@parker-howell.test",
"is_admin": false,
"dues_paid": null,
"owns_gi": true,
"has_first_aid_qualification": null,
"first_aid_achievement_date": null,
"first_aid_expiry_date": null,
"created_at": "2025-12-21T00:06:15.224Z",
"updated_at": "2025-12-21T00:06:15.224Z",
"last_sign_in_at": null,
"preferred_difference_editor_mode": null,
"effective_kyu_grade": 8
},
"relationships": {
"current_belt_grade": {
"data": {
"id": "3",
"type": "belt_grades"
}
},
"current_instructor_qualification": {
"data": {
"id": "1",
"type": "instructor_qualifications"
}
},
"belt_grades": {
"data": [
{
"id": "3",
"type": "belt_grades"
}
],
"links": {
"related": "/users/4/belt_grades"
}
},
"instructor_qualifications": {
"data": [
{
"id": "1",
"type": "instructor_qualifications"
}
],
"links": {
"related": "/users/4/instructor_qualifications"
}
},
"syllabi": {
"data": [],
"links": {
"related": "/users/4/syllabi"
}
}
}
},
"included": [
{
"id": "1",
"type": "instructor_qualifications",
"attributes": {
"achieved_at": "2025-12-21T00:00:00.000Z",
"user_id": 4,
"belt_id": 3,
"belt_grade_id": 3,
"created_at": "2025-12-21T00:06:15.315Z",
"updated_at": "2025-12-21T00:06:15.315Z",
"qualification_id": 1
},
"relationships": {
"user": {
"data": {
"id": "4",
"type": "users"
}
},
"belt": {
"data": {
"id": "3",
"type": "belts"
}
},
"belt_grade": {
"data": {
"id": "3",
"type": "belt_grades"
}
},
"qualification": {
"data": {
"id": "1",
"type": "qualifications"
}
}
}
}
]
}

[DEBUG] Users includes (instructor) - Included resources:
[
{
"id": "1",
"type": "instructor_qualifications",
"attributes": {
"achieved_at": "2025-12-21T00:00:00.000Z",
"user_id": 4,
"belt_id": 3,
"belt_grade_id": 3,
"created_at": "2025-12-21T00:06:15.315Z",
"updated_at": "2025-12-21T00:06:15.315Z",
"qualification_id": 1
},
"relationships": {
"user": {
"data": {
"id": "4",
"type": "users"
}
},
"belt": {
"data": {
"id": "3",
"type": "belts"
}
},
"belt_grade": {
"data": {
"id": "3",
"type": "belt_grades"
}
},
"qualification": {
"data": {
"id": "1",
"type": "qualifications"
}
}
}
}
]
returns current_instructor_qualification in JSON:API included when requested

Users minimal serialization

[DEBUG] Users minimal - Full payload:
{
"id": 6,
"first_name": "Angella",
"last_name": "Gislason",
"email": "clint@kerluke.test",
"is_admin": false,
"effective_kyu_grade": 7
}
returns minimal JSON with effective_kyu_grade when include is not provided

Finished in 2.99 seconds (files took 5.12 seconds to load)
4 examples, 0 failures

phablet@ubuntu-phablet:~/Documents/Tuff-City-Jiu-Jitsu-Api-Tablet$
