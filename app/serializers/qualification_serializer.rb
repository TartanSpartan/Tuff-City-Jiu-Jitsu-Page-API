class QualificationSerializer < ActiveModel::Serializer
    attributes(
    :id,
    :level,
    :created_at,
    :updated_at,
    :belt_id
  )

  belongs_to :belt
end