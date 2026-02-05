class SyllabusJsonapiSerializer
  include JSONAPI::Serializer

  set_type :syllabi
  attributes :country, :year

  has_many :belts, serializer: BeltJsonapiSerializer
end
