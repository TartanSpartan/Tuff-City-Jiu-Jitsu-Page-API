# Temporary ActiveModelSerializers profiler.
# Logs time spent in each serializer#serializable_hash to help find hotspots.
module AMSSerializerProfiler
  def serializable_hash(*args, &block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = super
    dur = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
    Rails.logger.info("[AMS-PROFILER] #{self.class.name} serializable_hash: #{'%.2f' % dur}ms")
    result
  end
end

if defined?(ActiveModel::Serializer)
  ActiveModel::Serializer.prepend(AMSSerializerProfiler)
else
  ActiveSupport.on_load(:active_model_serializers) do
    ActiveModel::Serializer.prepend(AMSSerializerProfiler)
  end
end

# Also instrument the JsonApi adapter if available to measure adapter-level cost
if defined?(ActiveModelSerializers::Adapter::JsonApi)
  module AMSAdapterProfiler
    def serializable_hash(*args, &block)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = super
      dur = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
      Rails.logger.info("[AMS-ADAPTER] #{self.class.name} serializable_hash: #{'%.2f' % dur}ms")
      result
    end
  end

  ActiveModelSerializers::Adapter::JsonApi.prepend(AMSAdapterProfiler)
end
