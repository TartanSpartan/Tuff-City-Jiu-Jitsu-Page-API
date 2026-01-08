class Api::V1::DifferencesController < Api::ApplicationController
  before_action :authenticate_api_v1_user!,
                only: %i[create update destroy index show]
  before_action :authorize_admin!, only: %i[create update destroy]
  before_action :set_difference, only: %i[show update destroy]

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  def index
    # We also apply includes here for good measure, anticipating requests like ?include=technique
    @differences =
      Difference
        .includes(:technique, compared_to_technique: { belt: :syllabus })
        .all
        .order(technique_id: :desc) # TODO: Why is it ordered like this, then by a different way for by_technique?

    render(
      json: @differences,
      each_serializer: DifferenceSerializer,
      include: sanitized_include
    )

    # TODO: Consider adding pagination here for better performance with large datasets.
    # e.g., @pagy, @differences = pagy(Difference.all.order(technique_id: :desc))
  end

  def create
    @difference = Difference.new(difference_params)

    if @difference.save
      render json: @difference,
             serializer: DifferenceSerializer,
             status: :created
    else
      render(
        json: {
          errors: @difference.errors.messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def show
    render(
      json: @difference,
      serializer: DifferenceSerializer,
      include: sanitized_include
    )
  end

  def update
    if @difference.update(difference_params)
      render json: @difference, serializer: DifferenceSerializer, status: :ok
    else
      render(
        json: {
          errors: @difference.errors.messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def destroy
    @difference.destroy
    head :no_content
  end

  def by_technique
    # Eager loading has been implemented: compared_to_technique -> belt -> syllabus
    # This action is used by the frontend to display all differences related to one technique.
    # We eagerly load the associations required for the include path: `compared_to_technique.belt.syllabus`
    @differences =
      Difference
        .where(technique_id: params[:technique_id])
        .includes(
          :technique,
          compared_to_technique: {
            belt: :syllabus
          } # Nested includes for Syllabus
        )
        .order(created_at: :desc) # Added a sensible order but TODO: why is it different from the index order?

    # The `include: params[:include]` ensures the serializer respects the user's sideloading request.
    render(
      json: @differences,
      each_serializer: DifferenceSerializer,
      include: sanitized_include
    )
  end

  private

  def sanitized_include
    # Sanitize the JSON:API include param against an allowlist to prevent
    # unexpected sideloads and limit serializer work.
    raw = params[:include]
    return nil if raw.blank?

    # Supported include paths:
    allowed = %w[
      technique
      compared_to_technique
      compared_to_technique.belt
      compared_to_technique.belt.syllabus
    ]

    requested = raw.is_a?(Array) ? raw : raw.to_s.split(",").map(&:strip)
    # Intersect requested with allowed; return a comma-separated string if any remain.
    (requested & allowed).presence&.join(",")
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_difference
    # *** EAGER LOADING UPDATED: compared_to_technique -> belt -> syllabus ***
    # This helper is used by `show` and `update/destroy`.
    # To support `?include=compared_to_technique.belt.syllabus`, we eagerly load these associations.
    @difference =
      Difference.includes(
        :technique, # Base technique
        compared_to_technique: {
          belt: :syllabus
        } # The nested sideloading path with Syllabus
      ).find(params[:id]) # TODO: consider harmonizing along the lines of other controllers i.e. using find_by for consistent semantics
  end

  # Only allow a list of trusted parameters through.
  def difference_params
    params.require(:difference).permit(
      :technique_id,
      :compared_to_technique_id,
      :content
    )
  end

  # Renders a 404 Not Found response for missing records.
  def record_not_found(error)
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

  # Renders a 422 Unprocessable Entity response for validation errors.
  def record_invalid(error)
    render json: {
             status: 422,
             errors: error.record.errors.full_messages
           },
           status: :unprocessable_entity
  end
end
