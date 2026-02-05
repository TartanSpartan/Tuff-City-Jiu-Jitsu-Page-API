# Configure default serialization strategy for syllabi endpoints.
# Allowed values: :presenter, :jsonapi, :ams
# Benchmarking showed the jsonapi-backed serializer to be the best all-round
# choice for `SyllabusLimitedSerializer` (balanced performance and compatibility),
# so set it as the global default here. Individual requests may still override
# with query params (?use_ams=true or ?use_jsonapi=true) when exercising the
# endpoint for testing or gradual rollouts.
Rails.application.config.syllabus_serialization_default = :jsonapi
