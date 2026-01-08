# frozen_string_literal: true
class TechniqueSerializer < ActiveModel::Serializer
  # Prefer relationships (JSON:API relationship linkage) instead of exposing raw *_id
  # attributes. Clients should follow relationship linkage rather than depending on
  # database primary keys in the attributes hash.
  attributes(:id, :summary, :default_attack, :created_at, :updated_at)

  # Belongs-to relationships: technique_type and belt are exposed as relationships
  # in the JSON:API payload.
  belongs_to :technique_type
  belongs_to :belt

  # Collections attached to a technique. These can be large (videos, differences)
  # so controllers should eager-load them when necessary to avoid N+1 queries.
  has_many :videos

  # Differences represent comparisons where this technique is the "subject" (the
  # base technique). The Difference model stores human-readable content describing
  # how the two techniques differ.
  has_many :differences

  # Comparisons are the inverse relationship: records where *this* technique is
  # the `compared_to_technique`. We include both associations because they have
  # different semantic meanings in the UI and may be displayed separately.
  # Example: `differences` are "A differs from B" entries where A is `technique`.
  # `comparisons` are entries where A is the `compared_to_technique` (B differs from A).
  # Keep both here for explicitness; serializers/tests should ensure they don't
  # duplicate the same logical comparison when rendering lists.
  has_many :comparisons, class_name: "Difference"
end
