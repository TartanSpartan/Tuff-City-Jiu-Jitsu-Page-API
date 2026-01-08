class BeltSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :colour,
    :kyu_number,
    :effective_kyu_grade,
    :created_at,
    :updated_at,
    :syllabus_id
  )

  # Method to calculate the effective kyu grade (1-8) for serialization
  def effective_kyu_grade
    raw_kyu = object.kyu_number
    # Calculation: ((raw_kyu - 1) % 8) + 1
    # This ensures that kyu numbers 1, 9, 17, etc., map to 1.
    # And kyu numbers 8, 16, 24, etc., map to 8. And so on!
    return nil unless raw_kyu.present? && raw_kyu.is_a?(Integer)
    ((raw_kyu - 1) % 8) + 1
  end

  # Includes all TechniqueTypes associated with this Belt.
  has_many :technique_types

  # Includes all Techniques associated with this Belt.
  has_many :techniques

  # Includes all BeltGrades associated with this Belt.
  has_many :belt_grades
end
