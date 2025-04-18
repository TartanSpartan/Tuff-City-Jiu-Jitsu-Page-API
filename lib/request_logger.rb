# lib/request_logger.rb
class RequestLogger
    def initialize(app)
      @app = app
    end
  
    def call(env)
      Rails.logger.debug "--- RequestLogger Middleware Processing ---"
      Rails.logger.debug "Request Method: #{env['REQUEST_METHOD']}"
      Rails.logger.debug "Request Path: #{env['PATH_INFO']}"
      Rails.logger.debug "Request Parameters: #{env['rack.request.form_hash']}"
      Rails.logger.debug "Script Name: #{env['SCRIPT_NAME']}"
      Rails.logger.debug "Rack Mount Point: #{env['rack.mount_point']}"
      Rails.logger.debug "Rack Route Info: #{env['rack.route_info']}" 
      Rails.logger.debug "--- Environment Variables ---"
      env.each { |k, v| Rails.logger.debug "#{k}: #{v}" if k.start_with?('HTTP_') || k.start_with?('rack.') }
      Rails.logger.debug "--- End RequestLogger Middleware ---"
  
      @app.call(env)
    end
  end