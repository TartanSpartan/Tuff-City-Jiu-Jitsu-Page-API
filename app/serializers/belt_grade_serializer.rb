class BeltGradeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :user_id,
    :belt_id
  )
  belongs_to :user
end