class Api::V1::BeltsController < Api::ApplicationController
  before_action :authenticate_api_v1_user!, except: %i[index show]
  before_action :authorize_admin!, only: %i[create destroy] # Add update here if that gets implemented
  before_action :find_belt, only: %i[show destroy]

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  def index
    # Ensure nested index correctly filters by syllabus if syllabus_id is present
    if params[:syllabus_id]
      syllabus = Syllabus.find_by!(id: params[:syllabus_id]) # Find the syllabus, raise error if not found
      belts = syllabus.belts.order(id: :asc) # Get belts associated with this syllabus in ascending order
    else
      belts = Belt.all.order(id: :asc) # Get all belts if not nested
    end

    # TODO: Check if the order still works with the addition of kyu_number, or if it needs to be tweaked for it

    render(json: belts, each_serializer: BeltSerializer)
  end

  def create
    # POST /api/v1/belts (or) /api/v1/syllabi/:syllabus_id/belts
    # Build the belt, associating it with the syllabus if syllabus_id is present in params
    if params[:syllabus_id]
      syllabus = Syllabus.find_by!(id: params[:syllabus_id]) # Ensure syllabus exists
      belt = syllabus.belts.build(belt_params) # Build belt through the syllabus association
    else
      belt = Belt.new(belt_params) # Create a standalone belt if not nested
    end

    begin
      belt.save!
      render json: belt, status: :created
    rescue ActiveRecord::RecordInvalid => e
      raise e # Re-raise to be handled by rescue_from
    rescue StandardError => e
      raise e # Re-raise unexpected errors
    end
  end

  def show
    # GET /api/v1/belts/:id
    # Returns a single belt by ID.
    render(json: @belt, serializer: BeltSerializer)
  end

  def destroy
    # DELETE /api/v1/belts/:id
    # Deletes a belt by ID.
    @belt.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  # def update
  #    PATCH/PUT /api/v1/belts/:id
  #    Updates a belt by ID.
  #    TODO: Assess if belt updates are even needed in the app. We're mostly just creating belts when setting up syllabi, but shouldn't need to do them live from the client or even the Rails console.
  #    Any updates envisioned would pertain to accounting for dan (black belt) grades, extra mons for yellow and orange belt and junior belt consideration but..
  #    Probably don't need to be added live. Still, let's discuss with other jitsuka and web developers to see what they think. No rush for this.
  #     if @belt.update belt_params
  #         render json: { id: @belt.id }
  #     else
  #         render(
  #             json: { errors: belt.errors },
  #             status: 422 # Unprocessable Entity
  #         )
  #     end
  # end

  def find
    # GET /api/v1/belts_find
    # Use params.fetch to safely get the 'belt' key, defaulting to an empty hash
    # This prevents ActionController::ParameterMissing error when no 'belt' key is present
    search_params =
      params
        .fetch(:belt, {})
        .permit(:colour, :kyu_number, :syllabus_id)
        .to_h
        .symbolize_keys # Convert to symbol keys for easier handling

    if search_params.empty?
      belts = Belt.all
    else
      # Case-insensitive match for colour when provided; apply any additional filters afterwards
      if search_params[:colour].present?
        colour = search_params.delete(:colour)
        belts = Belt.where("LOWER(colour) = ?", colour.to_s.downcase)
        belts = belts.where(search_params) if search_params.present?
      else
        belts = Belt.where(search_params)
      end
    end
    render json: belts, each_serializer: BeltSerializer
  end

  private

  def belt_params
    params.require(:belt).permit(
      :colour,
      :kyu_number,
      # Having :syllabus_id here to allows us to assign a syllabus during creation
      :syllabus_id
    )
  end

  def find_belt
    # Route: GET /api/v1/belts/:id or GET /api/v1/syllabi/:syllabus_id/belts/:id

    if params[:syllabus_id]
      # If nested, find the syllabus first, then find the belt through the syllabus association.
      # This ensures the belt belongs to the specified syllabus.
      syllabus = Syllabus.find_by!(id: params[:syllabus_id]) # Raise RecordNotFound if syllabus not found
      @belt = syllabus.belts.find_by!(id: params[:id]) # Raise RecordNotFound if belt not found OR not associated with syllabus
    else
      # If not nested, just find the belt by ID.
      @belt = Belt.find_by!(id: params[:id]) # Raise RecordNotFound if belt not found
    end
  end

  # Renders a JSON response for ActiveRecord::RecordNotFound errors.
  # This method is called by rescue_from and receives the error object.
  def record_not_found(error) # Accept the error object again
    Rails.logger.error("Record Not Found Error: #{error.message}") # Log the actual error message from the error object
    render(
      json: {
        status: 404,
        errors: {
          msg: "Record Not Found"
        }
      }, # Use 404 status for Not Found
      status: :not_found # Use the symbol for status
    )
  end

  # Renders a JSON response for ActiveRecord::RecordInvalid errors (validation errors, status 422).
  def record_invalid(error) # Accept the error object
    Rails.logger.error(
      "Record Invalid Error: #{error.record.errors.full_messages.join(", ")}"
    ) # Log validation errors
    invalid_record = error.record
    # Map errors to the desired JSON structure
    # Iterate over the error objects directly and access attribute and message
    errors =
      invalid_record.errors.map do |err| # Corrected iteration
        {
          field: err.attribute.to_s, # Access the attribute via the error object
          message: err.message # Access the message via the error object
        }
      end
    render(
      json: {
        status: 422,
        errors: errors
      },
      status: :unprocessable_entity # Explicitly set 422 status
    )
  end
end
