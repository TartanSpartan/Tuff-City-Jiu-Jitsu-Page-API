# frozen_string_literal: true
class InstructorQualificationSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :achieved_at,
    :user_id,
    :belt_id,
    :belt_grade_id,
    :created_at,
    :updated_at,
    :qualification_id
  )

  belongs_to :user
  belongs_to :belt
  belongs_to :belt_grade
  belongs_to :qualification
end
