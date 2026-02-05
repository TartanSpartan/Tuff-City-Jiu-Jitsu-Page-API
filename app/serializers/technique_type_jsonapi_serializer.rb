class TechniqueTypeJsonapiSerializer
  include JSONAPI::Serializer

  set_type :technique_types
  attributes :id, :category, :sub_category

  has_many :techniques, serializer: TechniqueJsonapiSerializer
end
