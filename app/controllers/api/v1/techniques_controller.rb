class Api::V1::TechniquesController < Api::ApplicationController
  before_action :authenticate_api_v1_user!, except: %i[index show]
  before_action :find_technique, only: %i[update destroy]
  before_action :authorize_user!, only: %i[create update destroy]
  before_action :set_technique_type, only: [:create]

  # Note to self: just refresh myself on difference between authentication and authorization here on Rails

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding pagination for the index action if the dataset grows large.
  # Also consider sanitizing JSON:API include parameters and eager loading associations
  # relevant to techniques (e.g., belt, syllabus via belt, technique_type, videos, differences)
  # to avoid N+1 queries.
  # This would be useful for efficient queries under index and the show action (via find_technique
  # or explicit includes used in show).
  # Finally, consider unifying record lookups (e.g., prefer `find` with `rescue_from` for 404s)
  # for consistency across controllers.

  def index
    # This filters techniques by syllabus when provided, otherwise returns all,
    # ordered by belt_id descending.
    if params[:syllabus_id].present?
      @techniques =
        Technique
          .includes(:technique_type, :belt)
          .joins(:technique_type)
          .where(technique_types: { syllabus_id: params[:syllabus_id] })
          .order(belt_id: :desc)
    else
      @techniques =
        Technique.includes(:technique_type, :belt).order(
          belt_id: :desc
        )
    end

    # Use a lightweight serializer for index/list endpoints to avoid loading
    # large associations like `videos`, `differences` or `comparisons` which
    # are unnecessary for simple lists and can trigger N+1 warnings.
    render json: @techniques, each_serializer: TechniqueLimitedSerializer
  end

  def create
    @technique = @technique_type.techniques.new(technique_params)

    if @technique.save
      # Returning the created technique object
      render json: @technique, status: :created
    else
      Rails.logger.error "Technique failed to save: #{@technique.errors.full_messages.join(", ")}"
      render json: {
               errors: @technique.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def show
    # Eager load the entire tree needed for deep JSON:API includes
    # (belt -> syllabus) and (differences -> compared_to_technique -> belt -> syllabus).
    @technique =
      Technique.includes(
        :belt, # Primary belt associated with the technique
        :technique_type, # Primary technique type
        videos: [], # Associated videos
        belt: :syllabus, # Ensure syllabus is loaded via the primary belt
        differences: {
          compared_to_technique: {
            belt: :syllabus
          }
        }
      ).find_by(id: params[:id])

    if @technique
      # Explicitly use the serializer for a single object
      render json: @technique, serializer: TechniqueSerializer
    else
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
  end

  def destroy
    @technique.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  def update
    if @technique.update(technique_params)
      render json: @technique, status: :ok
    else
      render(
        json: {
          errors: @technique.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  private

  # This method finds the TechniqueType. If it's not found, `find` raises a
  # `RecordNotFound` exception, which is caught by the `rescue` block in create,
  # preventing the 'save for nil' error.
  def set_technique_type
    # The `id` must be present in the parameters for this to work.
    technique_type_id = params.require(:technique)[:technique_type_id]
    @technique_type = TechniqueType.find(technique_type_id)
  end

  def technique_params
    params.require(:technique).permit(
      # Replace these as appropriate
      :summary,
      :default_attack,
      :technique_type_id,
      :belt_id,
      videos_attributes: %i[id url country year _destroy]
    )
  end

  def find_technique
    @technique ||= Technique.find params[:id]
  end

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
    render json: {
             status: 422,
             errors: error.record.errors.full_messages
           },
           status: :unprocessable_entity
  end

  def authorize_user!
    unless current_api_v1_user&.is_admin?
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end
end
