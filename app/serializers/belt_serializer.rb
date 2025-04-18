class BeltSerializer < ActiveModel::Serializer
  attributes(
    :id, 
    :colour,
    :created_at, 
    :updated_at
)
end