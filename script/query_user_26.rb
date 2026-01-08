# frozen_string_literal: true

u = User
  .includes(:waiver, :user_syllabi, :syllabi,
            :instructor_qualifications, :belt_grades, :qualifications)
  .find_by(id: 26)

if u.nil?
  puts "User 26 not found"
  exit 0
end

puts "User Summary"
puts({ id: u.id, email: u.email, name: u.full_name, admin: u.is_admin? })

puts "\nWaiver"
w = u.waiver
puts(w&.attributes&.slice('id','signed_on','participant_name','organization_witness_name') || 'nil')

puts "\nUserSyllabi"
puts u.user_syllabi.pluck(:id, :syllabus_id).map { |id, sid| { id: id, syllabus_id: sid } }

puts "\nSyllabi"
puts u.syllabi.pluck(:id, :country, :year).map { |id, country, year| { id: id, country: country, year: year } }

puts "\nInstructorQualifications"
iq = u.instructor_qualifications.order(achieved_at: :desc)
puts iq.pluck(:id, :qualification_id, :belt_id, :achieved_at, :effective_qualification_id).map { |id, qid, bid, at, eq|
  { id: id, qualification_id: qid, belt_id: bid, achieved_at: at, effective_qualification_id: eq }
}

puts "\nQualifications (through instructor_qualifications)"
puts u.qualifications.pluck(:id, :level, :belt_id).map { |id, level, bid| { id: id, level: level, belt_id: bid } }

puts "\nBeltGrades"
bg = u.belt_grades.order(obtained_at: :desc)
puts bg.map { |g| { id: g.id, belt_id: g.belt_id, grade_name: g.grade_name, obtained_at: g.obtained_at, effective_kyu_grade: g.effective_kyu_grade } }

puts "\nCurrentBeltGrade"
cbg = u.current_belt_grade
puts(cbg&.attributes&.slice('id','belt_id','obtained_at','effective_kyu_grade') || 'nil')

puts "\nCurrentInstructorQualification"
ciq = u.current_instructor_qualification
puts(ciq&.attributes&.slice('id','qualification_id','belt_id','achieved_at','effective_qualification_id') || 'nil')

puts "\nCounts"
puts({
  user_syllabi_count: u.user_syllabi.size,
  syllabi_count: u.syllabi.size,
  instructor_qualifications_count: u.instructor_qualifications.size,
  belt_grades_count: u.belt_grades.size,
  qualifications_count: u.qualifications.size
})
