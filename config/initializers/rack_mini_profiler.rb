if defined?(Rack::MiniProfiler)
  # Show the profiler on the right and make it visible by default in development
  Rack::MiniProfiler.config.position = 'right'
  Rack::MiniProfiler.config.start_hidden = false
end
