class Api::V1::TechniqueTypesController < Api::ApplicationController
  before_action :set_technique_type, only: %i[show update destroy]
  before_action :authenticate_api_v1_user!, only: %i[create update destroy]
  before_action :authorize_admin!, only: %i[create update destroy]

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding pagination for the index action if the dataset grows large.
  # Also consider sanitizing JSON:API include parameters and eager loading associations
  # relevant to technique types (e.g., belt, syllabus, techniques) to avoid N+1 queries.
  # This would be useful for efficient queries under index and the show action (via set_technique_type).
  # Finally, consider changing the custom `find` action to use `find_by!` (read-only) and move creation
  # concerns to `create`, to align with best practices elsewhere and keep responsibilities clear.

  # GET /api/v1/technique_types
  def index
    @technique_types = TechniqueType.all.order(belt_id: :desc)
    # Use the correct `each_serializer` option for collections.
    render json: @technique_types, each_serializer: TechniqueTypeSerializer
  end

  # GET /api/v1/technique_types/:id
  def show
    # The `set_technique_type` before_action handles finding the record.
    # If the record is not found, the rescue_from block will be triggered.
    render json: @technique_type, serializer: TechniqueTypeSerializer
  end

  def create
    @technique_type = TechniqueType.new(technique_type_params)
    if @technique_type.save
      render json: @technique_type,
             serializer: TechniqueTypeSerializer,
             status: :created
    else
      # Render JSON API-compliant errors
      render json: {
               errors: @technique_type.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def destroy
    @technique_type.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  def update
    if @technique_type.update(technique_type_params)
      # The corrected line: simply pass the object to the renderer.
      render json: @technique_type,
             serializer: TechniqueTypeSerializer,
             status: :ok
    else
      render(
        json: {
          errors: @technique_type.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def find
    @technique_type = TechniqueType.find_by(technique_type_params)

    unless @technique_type
      @technique_type = TechniqueType.new(technique_type_params)
      if @technique_type.save
        render json: @technique_type,
               serializer: TechniqueTypeSerializer,
               status: :created and return
      else
        Rails.logger.warn(
          "TechniqueType validation errors: #{@technique_type.errors.full_messages.inspect}"
        )
        render json: {
                 errors: @technique_type.errors.full_messages
               },
               status: :unprocessable_entity and return
      end
    end

    render json: @technique_type, serializer: TechniqueTypeSerializer
  end

  def search
    # Find all technique types where the category matches the search query.
    # The `ILIKE` operator provides a case-insensitive search.
    technique_types =
      TechniqueType.where("category ILIKE ?", "%#{params[:query]}%")

    # Render the collection of results. `is_collection: true` is required here as well.
    render json: technique_types, each_serializer: TechniqueTypeSerializer
  end

  private

  def technique_type_params
    params.require(:technique_type).permit(
      :category,
      :sub_category,
      :syllabus_id,
      :belt_id
    )
  end

  def set_technique_type
    @technique_type = TechniqueType.find(params[:id])
  end

  # def find_technique_type
  #     @technique_type ||= TechniqueType.find(params[:id])
  # end

  def record_not_found
    render(
      json: {
        status: 404,
        errors: {
          msg: "Record Not Found"
        }
      },
      status: :not_found
    )
  end

  def record_invalid(error)
    invalid_record = error.record
    errors =
      invalid_record.errors.map do |field, message|
        {
          type: error.class.to_s,
          record_type: invalid_record.class.to_s,
          field: field,
          message: message
        }
      end
    render(json: { status: 422, errors: errors }, status: :unprocessable_entity)
  end
end
