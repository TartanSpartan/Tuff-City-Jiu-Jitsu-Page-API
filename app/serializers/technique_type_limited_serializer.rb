class TechniqueTypeLimitedSerializer < ActiveModel::Serializer
  attributes :id, :category, :sub_category

  # Expose techniques as a relationship so ActiveModelSerializers will
  # populate them in the JSON:API `included` array. Use the lightweight
  # `TechniqueLinkSerializer` to keep the payload small.
  has_many :techniques, serializer: TechniqueLinkSerializer

  def serializable_hash(*args, &block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = super
    dur = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
    Rails.logger.info("[AMS-LOCAL-PROFILER] #{self.class.name} serializable_hash: #{'%.2f' % dur}ms")
    result
  end
end


