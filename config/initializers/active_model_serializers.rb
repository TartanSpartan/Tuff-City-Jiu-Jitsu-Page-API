# This file configures the Active Model Serializers gem to produce
# a JSON API-compliant output. The settings here ensure a consistent
# and well-structured response format across your API.
#
# The `:json_api` adapter is a powerful choice that standardizes
# your API's responses, making them easier for clients to consume.
ActiveModelSerializers.config.adapter = :json_api

# This setting ensures that all attribute names in the JSON response use
# underscores, matching standard Rails and RSpec conventions (e.g., `created_at`
# instead of `createdAt`). This is a best practice for consistency.
ActiveModelSerializers.config.key_transform = :underscore

# The JSON API specification includes top-level `meta` and `links` keys
# by default. By setting this to `false`, we can opt out of including
# these keys in every response, resulting in a cleaner output when they
# are not needed. You can still add them on a per-serializer basis.
ActiveModelSerializers.config.jsonapi_include_toplevel_meta_and_links = false

# This setting ensures that resource types in the JSON are plural
# (e.g., "technique_types"). This provides a consistent naming convention
# that matches how you would refer to a series of resources. But what
# out for other serializer test failures, just in case.
ActiveModelSerializers.config.jsonapi_resource_type = :plural

# The following settings are for documentation purposes and illustrate
# how you can customize the adapter further. While not strictly
# necessary for your current tests, they are useful for future
# development and can be uncommented as needed.
#
# ActiveModelSerializers.config.jsonapi_pagination_links_enabled = true
# ActiveModelSerializers.config.jsonapi_page_number_key = :page
# ActiveModelSerializers.config.jsonapi_page_size_key = :per_page
# ActiveModelSerializers.config.jsonapi_default_page_size = 10
