# frozen_string_literal: true

class DifferenceSerializer < ActiveModel::Serializer
  # Specifies which attributes of the model should be serialized.
  # This includes the primary key, the content, and the timestamps.
  attributes(:id, :content, :created_at, :updated_at)
  # Establishes a has-one relationship to the `technique` model,
  # ensuring that the associated technique data is included in the JSON.
  # The serializer will look for a `TechniqueSerializer` by convention.
  belongs_to :technique

  # Establishes another belongs_to relationship, this time for the
  # compared-to technique. Use an explicit serializer so AMS finds the
  # expected serializer class regardless of naming conventions.
  belongs_to :compared_to_technique, serializer: TechniqueSerializer
end
