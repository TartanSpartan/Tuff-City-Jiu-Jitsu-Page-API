module Api
  module V1
    class ErrorsController < Api::ApplicationController
      # Test-only action to raise an error and validate 500 payload shape
      def boom
        raise StandardError, "Test-triggered internal error"
      end
    end
  end
end
