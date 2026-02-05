class BeltSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :colour,
    :kyu_number,
    :effective_kyu_grade,
    :created_at,
    :updated_at,
    :syllabus_id
  )

  # Method to calculate the effective kyu grade (1-8) for serialization
  def effective_kyu_grade
    raw_kyu = object.kyu_number
    # Calculation: ((raw_kyu - 1) % 8) + 1
    # This ensures that kyu numbers 1, 9, 17, etc., map to 1.
    # And kyu numbers 8, 16, 24, etc., map to 8. And so on!
    return nil unless raw_kyu.present? && raw_kyu.is_a?(Integer)
    ((raw_kyu - 1) % 8) + 1
  end

  # Includes all TechniqueTypes associated with this Belt.
  has_many :technique_types

  # Use a lightweight technique-type serializer for lists to avoid pulling
  # videos, differences and comparisons into index-like responses.
  has_many :technique_types, serializer: TechniqueTypeLimitedSerializer

  def serializable_hash(*args, &block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = super
    dur = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
    Rails.logger.info("[AMS-LOCAL-PROFILER] #{self.class.name} serializable_hash: #{'%.2f' % dur}ms")
    result
  end

  # Do not include `techniques` or `belt_grades` here by default — those
  # inflate the payload and cause heavy serialization work. Technique lists
  # are provided via the `TechniqueTypeLimitedSerializer` above as simple
  # link objects.
end
