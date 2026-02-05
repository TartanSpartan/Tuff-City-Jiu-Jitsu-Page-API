class TechniqueLimitedSerializer < ActiveModel::Serializer
  attributes :id, :summary

  # Keep relationships lightweight so list endpoints don't pull large collections
  # like videos, differences or comparisons.
  belongs_to :technique_type
  belongs_to :belt
end
