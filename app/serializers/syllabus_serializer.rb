class SyllabusSerializer < ActiveModel::Serializer
  attributes(:id, :country, :year, :is_primary_admin_syllabus, :is_secondary_admin_syllabus, :created_at, :updated_at)

  # Includes all Belts associated with this Syllabus.
  has_many :belts

  # Includes all TechniqueTypes associated with this Syllabus.
  # Note: The BeltSerializer will also include TechniqueTypes, but
  # having this direct association here is useful for top-level queries.
  has_many :technique_types

  # Note: Default AMS relationship serialization will provide the JSON:API relationships.
end
