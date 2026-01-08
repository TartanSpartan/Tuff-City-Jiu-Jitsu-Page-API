module SerializerHelpers
  # Serialize a resource (model or serializer) to a parsed JSON API hash.
  # - resource_or_serializer: either an ActiveModel::Serializer instance or a model instance
  # - includes: array of associations to include (symbols)
  # - context: hash passed into the serialization context
  def serialize_json_api(resource_or_serializer, includes: [], context: {})
    serializer =
      if resource_or_serializer.is_a?(ActiveModel::Serializer)
        resource_or_serializer
      else
        # Try to resolve a serializer for the resource; fall back to using
        # the resource directly if no serializer is registered.
        serializer_class =
          ActiveModelSerializers::SerializableResource.new(
            resource_or_serializer
          ).serializer
        serializer_class.new(resource_or_serializer)
      end

    adapter =
      ActiveModelSerializers::Adapter::JsonApi.new(
        serializer,
        include: includes,
        serialization_context:
          ActiveModelSerializers::SerializationContext.new(context)
      )

    JSON.parse(adapter.to_json)
  end

  def serialized_attributes(resource_or_serializer, includes: [], context: {})
    serialize_json_api(
      resource_or_serializer,
      includes: includes,
      context: context
    )[
      "data"
    ][
      "attributes"
    ]
  end
end

RSpec.configure { |config| config.include SerializerHelpers }
