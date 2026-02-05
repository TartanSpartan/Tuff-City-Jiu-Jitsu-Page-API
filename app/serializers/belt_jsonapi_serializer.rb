class BeltJsonapiSerializer
  include JSONAPI::Serializer

  set_type :belts
  attributes :id, :colour, :kyu_number, :created_at, :updated_at, :syllabus_id

  attribute :effective_kyu_grade do |belt, params|
    if belt.kyu_number.respond_to?(:to_i)
      ((belt.kyu_number - 1) % 8) + 1
    end
  end

  has_many :technique_types, serializer: TechniqueTypeJsonapiSerializer
end
