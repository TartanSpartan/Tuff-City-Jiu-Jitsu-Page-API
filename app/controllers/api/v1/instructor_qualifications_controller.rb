class Api::V1::InstructorQualificationsController < Api::ApplicationController
  before_action :authenticate_api_v1_user!
  before_action :authorize_admin!, only: %i[create update destroy]
  before_action :find_instructor_qualification, only: %i[show update destroy]

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding pagination for index action if the dataset grows large.
  # Also, whether the client would benefit from sanitation of include parameters here on the API, along with eager loading.
  # This would be useful for efficient queries under index and set_instructor_qualification for the show action.
  # Finally, consider changing find to find_by to align with best practices elsewhere across the controllers.

  def index
    # Admins can see all instructor qualifications; ordinary users see only their own
    @instructor_qualifications =
      if current_api_v1_user&.is_admin?
        InstructorQualification.order(created_at: :desc)
      else
        current_api_v1_user.instructor_qualifications.order(created_at: :desc)
      end
    render(
      json: @instructor_qualifications,
      each_serializer: InstructorQualificationSerializer
    )
  end

  def show
    # Only the owner or an admin may view a specific instructor qualification
    if current_api_v1_user&.is_admin? ||
         @instructor_qualification.user_id == current_api_v1_user&.id
      render json: @instructor_qualification,
             serializer: InstructorQualificationSerializer
    else
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end

  def create
    @instructor_qualification =
      current_api_v1_user.instructor_qualifications.new(
        instructor_qualification_params
      )

    if @instructor_qualification.save
      render json: @instructor_qualification, status: :created
    else
      render(
        json: {
          errors: @instructor_qualification.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def update
    if @instructor_qualification.update instructor_qualification_params
      render json: @instructor_qualification, status: :ok
    else
      render(
        json: {
          errors: @instructor_qualification.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def destroy
    @instructor_qualification.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  private

  def instructor_qualification_params
    params.require(:instructor_qualification).permit(
      :achieved_at,
      :belt_id,
      :belt_grade_id,
      :qualification_id
    )
  end

  def find_instructor_qualification
    @instructor_qualification ||= InstructorQualification.find params[:id]
  end

  def record_not_found(_error = nil)
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
    render(
      json: {
        status: 422,
        errors: error.record.errors.full_messages
      },
      status: :unprocessable_entity
    )
  end

  def authorize_admin!
    unless current_api_v1_user&.is_admin?
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end
end
