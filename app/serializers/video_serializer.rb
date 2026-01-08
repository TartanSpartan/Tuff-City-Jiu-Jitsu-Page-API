class VideoSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :url,
    :country,
    :year,
    :created_at,
    :updated_at,
    :technique_id
    )

  has_one :technique
end
