module Api
  module V1
    # WaiversController handles creation and management of waivers.
    # Notes / TODOs (salvaged ideas):
    # - Consider extracting authorize helpers (authorize_admin!, authorize_owner_or_admin!)
    #   for readability and consistency across controllers.
    # - Consider removing :user_id from strong params and always assign via current user
    #   to avoid privilege escalation.
    # - Prefer consistent error shapes across controllers: 404/422/400/500 as below.
    # - Prefer AMS serialization for consistent responses via WaiverSerializer.
    class WaiversController < Api::ApplicationController
      before_action :authenticate_api_v1_user!, except: %i[create show]
      before_action :set_waiver, only: %i[show update destroy]

      rescue_from StandardError, with: :handle_internal_server_error
      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActionController::ParameterMissing, with: :bad_request

      def outstanding_count
        # GET /api/v1/waivers/outstanding_count
        # Custom action to retrieve the count of waivers awaiting admin signature. (requires admin privileges
        unless current_api_v1_user&.is_admin?
          return render json: { error: "Unauthorized" }, status: :forbidden
        end

        # Call the class method defined in the Waiver model
        count = Waiver.outstanding_count
        render json: { outstanding_count: count }, status: :ok
      end

      def index
        # GET /api/v1/waivers
        if current_api_v1_user&.is_admin?
          # Eager-load the user and common nested associations used by the
          # `UserSerializer` to avoid per-user queries (N+1) when serializing
          # large waiver collections. Keep this minimal — add more associations
          # here only if the serializer starts referencing them.
          @waivers =
            Waiver.includes(
              user: %i[belt_grades instructor_qualifications syllabi]
            ).all
          render json: @waivers, each_serializer: WaiverSerializer, status: :ok
        else
          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end

      def show
        # Show is publicly accessible per request specs; render the waiver if found so that the user can view the waiver they just signed
        # TODO: Ensure that user settings page, when created, will retrieve the waiver so they can see it whenever they choose
        render json: @waiver, serializer: WaiverSerializer, status: :ok
      end

      def create
        # POST /api/v1/waivers
        # TODO: Public create endpoint may benefit from throttling/CAPTCHA in the product version to guard against bots and other malcious actors.
        if Rails.env.development?
          Rails.logger.debug(
            "Waivers#create: params received: #{params.to_unsafe_h}"
          )
        end
        @waiver = Waiver.new(waiver_params)
        @waiver.user = current_api_v1_user if current_api_v1_user.present?

        if @waiver.save
          Rails.logger.info "Waivers#create: waiver #{@waiver.id} created successfully"
          render json: @waiver, serializer: WaiverSerializer, status: :created
        else
          Rails.logger.warn "Waivers#create: validation failed: #{@waiver.errors.full_messages}"
          render json: {
                   status: 422,
                   errors: @waiver.errors.full_messages
                 },
                 status: :unprocessable_entity
        end
      end

      def update
        # PUT /api/v1/waivers/:id
        unless current_api_v1_user&.is_admin? ||
                 (@waiver.user == current_api_v1_user)
          return render json: { error: "Unauthorized" }, status: :forbidden
        end

        if @waiver.update(waiver_params)
          render json: @waiver, serializer: WaiverSerializer, status: :ok
        else
          Rails.logger.warn "Waivers#update: validation failed: #{@waiver.errors.full_messages}"
          render json: {
                   status: 422,
                   errors: @waiver.errors.full_messages
                 },
                 status: :unprocessable_entity
        end
      end

      def destroy
        # DELETE /api/v1/waivers/:id
        unless current_api_v1_user&.is_admin?
          return render json: { error: "Unauthorized" }, status: :forbidden
        end

        @waiver.destroy
        head :no_content
      end

      private

      def set_waiver
        # Use find with rescue_from for consistent 404 behavior
        @waiver = Waiver.find(params[:id])
      end

      def waiver_params
        params.require(:waiver).permit(
          :participant_name,
          :participant_email_address,
          :initials,
          :participant_address,
          :participant_signature,
          :organization_witness_name,
          :organization_witness_signature,
          :participant_date_of_birth,
          :participant_phone,
          :emergency_contact_name,
          :emergency_contact_number,
          :relationship,
          :signed_on,
          :user_id # TODO: Consider removing and always assigning via current user
        )
      end

      def record_not_found
        Rails.logger.warn "Waivers: record not found for id=#{params[:id]}"
        render json: {
                 status: 404,
                 errors: {
                   msg: "Record Not Found"
                 }
               },
               status: :not_found
      end

      def handle_internal_server_error(exception)
        Rails.logger.error "Waivers: internal error: #{exception.class}: #{exception.message}\n#{exception.backtrace&.first(5)&.join("\n")}"
        render json: {
                 status: 500,
                 errors: {
                   msg: "Internal Server Error: #{exception.message}"
                 }
               },
               status: :internal_server_error
      end

      def bad_request(exception)
        Rails.logger.warn "Waivers: bad request: #{exception.message}"
        render json: {
                 status: 400,
                 errors: {
                   msg: exception.message
                 }
               },
               status: :bad_request
      end
    end
  end
end
