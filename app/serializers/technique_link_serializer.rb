class TechniqueLinkSerializer < ActiveModel::Serializer
  # Minimal representation for index/list views — client will fetch details
  # on demand using the technique id or construct a link.
  attributes :id, :summary

  def serializable_hash(*args, &block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = super
    dur = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
    Rails.logger.info("[AMS-LOCAL-PROFILER] #{self.class.name} serializable_hash: #{'%.2f' % dur}ms")
    result
  end
end
