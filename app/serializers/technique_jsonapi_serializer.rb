class TechniqueJsonapiSerializer
  include JSONAPI::Serializer

  set_type :techniques
  attributes :id, :summary
end
