class WaiverSerializer < ActiveModel::Serializer
  # Note: `optional: true` is primarily a model-level option (ActiveRecord) used to
  # indicate the association may be absent. ActiveModel::Serializer does not use
  # `optional:` — this is left here as documentation to signal that a Waiver may
  # not always have an associated `user`.
  #
  # When serializing collections that include `user` (or nested user data), make
  # sure callers (controllers) eager-load `:user` to avoid N+1 queries, e.g.
  #   Waiver.includes(:user)
  belongs_to :user, optional: true

  # This serializer exposes PII and signature fields (names, email,
  # phone, date of birth, participant_signature, organization_witness_signature).
  # We should consider gating these fields behind authorization checks (e.g. pass
  # `is_admin: true` into `SerializableResource` via `instance_options` or
  # provide a separate public-facing serializer) so sensitive data isn't leaked
  # to unauthorised consumers.
  attributes(
    :id,
    :participant_name,
    :initials,
    :participant_email_address,
    :participant_address,
    :participant_signature,
    :participant_date_of_birth,
    :participant_phone,
    :organization_witness_name,
    :organization_witness_signature,
    :emergency_contact_name,
    :emergency_contact_number,
    :relationship,
    :signed_on,
    :created_at,
    :updated_at
  )
end

# TODOs:
# - Gating / PII: This serializer exposes sensitive PII fields (email, phone,
#   date_of_birth, signatures). Consider adding an explicit gating mechanism so
#   controllers or the serialization context can opt into PII (for example,
#   pass `serialization_context: { include_pii: true }` or set an
#   `instance_options[:is_admin]` flag). If gating is used, prefer a white-list
#   approach and document which endpoints are allowed to request the PII-rich
#   representation.
#
# - Serializer variants: Consider adding a lightweight public-facing serializer
#   (e.g. `WaiverPublicSerializer`) that exposes only non-PII fields and use it
#   for unauthenticated endpoints (like `show` after create). This makes it
#   harder to accidentally return private data from other controllers.
#
# - Eager-loading / performance: When serializing collections that include
#   `user` (e.g. `include: ['user']`) callers should eager-load the associated
#   user and any user nested associations referenced by `UserSerializer` to
#   avoid N+1 queries. Example:
#     Waiver.includes(user: [:belt_grades, :instructor_qualifications, :syllabi])
#
# - "current" has_one accessors: `UserSerializer` references `current_belt_grade`
#   and `current_instructor_qualification` which ActiveRecord often resolves via
#   per-record ORDER/LIMIT queries. If N+1 issues persist, consider computing
#   the "current" items from preloaded collections in the serializer (use the
#   preloaded `belt_grades` and pick the latest in Ruby), or add a denormalized
#   `current_belt_grade_id` on `users` maintained by application logic.
#
# - Tests: Keep the existing DB-backed included-user test and a light N+1 guard
#   in `spec/serializers/waiver_serializer_spec.rb`. If we add gating, add
#   tests for both gated (admin) and public (non-PII) outputs.
