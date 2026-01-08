class BeltGradeSerializer < ActiveModel::Serializer
  # Serializes a single BeltGrade.
  # - `time_held` and `grade_name` are virtual/computed instance methods defined by the model.
  attributes :id,
             :user_id,
             :belt_id,
             :obtained_at,
             :effective_kyu_grade,
             :grade_name,
             :time_held,
             :created_at,
             :updated_at

  belongs_to :user
  belongs_to :belt
end
