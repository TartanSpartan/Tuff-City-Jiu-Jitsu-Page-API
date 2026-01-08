class Api::V1::BeltGradesController < Api::ApplicationController
  # This controller has the canonical order of methods, all other controllers should follow it
  before_action :authenticate_api_v1_user!
  # Check if the name of the following before_action is correct terminology
  before_action :authorize_admin!, only: %i[create update destroy]
  before_action :find_belt_grade, only: %i[show update destroy]

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  def index
    # Returns a list of all belt grades for an admin, or a list of the current user's belt grades for a regular user.
    if current_api_v1_user&.is_admin?
      belt_grades = BeltGrade.all.order(id: :desc)
    else
      # Scope the query to the current user's belt grades.
      belt_grades = BeltGrade.where(user: current_api_v1_user).order(id: :desc)
    end
    render(json: belt_grades)
  end

  def show
    # A regular user can only view their own belt grade. An admin can view any.
    if @belt_grade.user == current_api_v1_user || current_api_v1_user&.is_admin?
      render(json: @belt_grade)
    else
      # Deny access if the user is not the owner and is not an admin.
      render(
        json: {
          status: 403,
          errors: {
            msg: "Access Denied"
          }
        },
        status: :forbidden
      )
    end
  end

  def create
    # A belt grade represents "what colour of belt is a user?", so a user who's starting for the first time
    # will have a Belt ID of 8 i.e. white belt, a club instructor is probably a brown belt so a Belt ID of 1, etc.
    @belt_grade = BeltGrade.new(belt_grade_params)

    if @belt_grade.save
      render json: @belt_grade, status: :created
    else
      render json: {
               errors: @belt_grade.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def update
    if @belt_grade.update(belt_grade_params)
      render json: @belt_grade, status: :ok
    else
      render(
        json: {
          errors: @belt_grade.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def destroy
    @belt_grade.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  private

  def belt_grade_params
    params.require(:belt_grade).permit(:user_id, :belt_id, :obtained_at)
  end

  def find_belt_grade
    @belt_grade ||= BeltGrade.find_by!(id: params[:id])
  end

  # Renders a 404 Not Found response for missing records.
  def record_not_found(_error)
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

  # TODO: Add logging for admin actions (maybe they make a mistake for which belt grade to update or assign)

  def authorize_admin!
    unless current_api_v1_user&.is_admin?
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end
end
