# frozen_string_literal: true
class TechniqueTypeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :category,
    :sub_category,
    :created_at,
    :updated_at
  )

  # Include the full associated Belt and Syllabus objects
  # This makes the API response much more useful as it includes all the
  # details for the belt and syllabus without needing a separate API call.
  belongs_to :syllabus
  belongs_to :belt

  # NOTE: Including full `belt`/`syllabus` and the `techniques` collection can
  # significantly increase payload size and may introduce N+1 query risks when
  # serializing lists. Controllers that render collections should eager-load
  # these associations (e.g. `TechniqueType.includes(:belt, :syllabus, :techniques)`)
  # or request included resources explicitly via the adapter (e.g. `include: ['techniques']`).
  # For index endpoints prefer relationship linkage or a lightweight serializer
  # (e.g. `TechniqueLiteSerializer`) and paginate the `techniques` association.

  # Include the associated techniques for this technique type
  has_many :techniques
end
