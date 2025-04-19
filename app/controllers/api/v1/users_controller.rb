class Api::V1::UsersController < Api::ApplicationController
#   before_action :authenticate_user!, except: [:create, :email_available, :current]
  before_action :authenticate_api_v1_user!, except: [:create, :email_available] 
  before_action :find_user, only: [:show, :update] # Add destroy action to here, and write the definition for it, if myself and fellow instructors, students, etc agree that it should be implemented
  before_action :authorize_user!, except: [:create, :email_available, :current]
  before_action :authorize_user!, only: [:update, :show] # Admins are the only class of users who can update or delete other users; see the find_user line and same applies here

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

    def current
        if current_api_v1_user
            render json: current_api_v1_user
        else
            render json: { error: "No current user"}, status: :unauthorized
        end
    end

  def index
      users = User.order(created_at: :desc)
      puts "These are the users", users
      render(json: users)
  end

  def create
    # Because we're gradually bringing in functionality from an old version of the project, we don't want user creation
    # to fail and create a partially finished database entry if for example the InstructorQualification logic isn't quite
    # re-implemented yet. So, we use atomic database transactions; if any part of the block fails or raises ActiveRecord::
    # Rollback, then all database changes made within the block are undone. This is useful because, for example, it means
    # attempting to sign up with an email in this state of development will fail but will **not** prevent the same email 
    # from being able to successfully sign up later when the functionality is there. This is "an atomic transaction" pattern.

    ActiveRecord::Base.transaction do
      @user = User.new(user_params)

      # user = User.new first_name: params["first_name"], last_name: params["last_name"], email: params["email"]

      # user.save!
      # user.inspect

      # Check for validation errors using the if condition
      if @user.save
        # Next, we need to create a belt grade for the user, setting the belt id to 8/white (by default we assume new students 
        # are white belts, but also they may be joining with a higher belt on their waist), and the admin can update it later 
        # as appropriate e.g. when they pass gradings
        belt_grade = BeltGrade.create!(user_id: @user.id, belt_id: 8)

        # And an instructor qualification (likewise, a meaningless "unqualified" qualification with ID = 1 for now, to be updated
        # if and when  the user gets new qualifications)
        InstructorQualification.create!(
          user_id: @user.id,
          belt_grade_id: belt_grade.id, # Match association with the newly created belt_grade
          belt_id: 8,
          qualification_id: 1)

        # If each database operation passed succesffuly, then we can initiate the session and render a success message
        session[:user_id] = @user.id
        render json: {id: @user.id, message: "User created and signed in successfully"}, status: :created
      else 
        # Because user validation failed in this case, we should render errors and explicitly rollback the transaction from saving to the DB
        render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end

    rescue ActiveRecord::RecordInvalid => e
      # Now we'll perform error handling via rescue in the case of validation errors for those save and create calls
      Rails.logger.error "User creation failed due to validation errors on #{e.record.class.name}: #{e.record.errors.full_messages.join(', ')}"
      # This catches validation errors from User.save!, BeltGrade.create! or InstructorQualification.create!
      #  e.record contains the object that failed validation
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      # This should also cause a rollback
      raise ActiveRecord::Rollback

      # Miscellaneous ActiveRecord errors need to be rescued from, too, e.g. RecordNotFound
    rescue StandardError => e
      Rails.logger.error "User creation failed due to unexpected error: #{e.message}"
      render json: { errors: ["Errors prevented user creation"] }, status: :internal_server_error
      raise ActiveRecord::Rollback
    end

  end

  def update
    user = User.find(params[:id])

    belt_grade = BeltGrade.find_by!(user_id: user.id)
    belt_grade.update!(belt_id: params[:belt_id].to_i) if params[:belt_id].present?

    instructor_qualification = InstructorQualification.find_by!(user_id: user.id)
    if params[:instructor_qualification].present?
        instructor_qualification.update!(qualification_params)
    end

    user.update!(
        owns_gi: params[:owns_gi],
        has_first_aid_qualification: params[:has_first_aid_qadvualification],
        first_aid_achievement_date: params[:first_aid_achievement_date],
    )

    render json: { message: "User updated successfully" }, status: :ok

    rescue ActiveRecord::RecordNotFound => e
        render json: { error: "#{e.model} not found" }, status: :not_found

    rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def email_available
    if params[:email].present?
      render json: { available: !User.exists?(email: params[:email]) }, status: :ok
    else
      render json: { error: "Email param missing" }, status: :bad_request
    end
  end

  def show
    if @user
      render json: @user
    else
      render json: { error: "User Not Found" }, status: :not_found
    end
  end

  private

    def user_params
        params.require(:user)
        .permit(
            :id,
            :first_name,
            :last_name,
            :email,
            :is_admin,
            :dues_paid,
            :owns_gi,
            :has_first_aid_qualification,
            :first_aid_achievement_date,
            :first_aid_expiry_date,
            :password,
            :password_confirmation,
            :created_at,
            :updated_at,
            belt_grade_attributes: [:id, :user_id, :belt_id],
            instructor_qualification_attributes: [:id, :user_id, :belt_grade_id, :belt_id, :qualification_id, :achieved_at]
        )
    end

    def qualification_params
        params.require(:instructor_qualification).permit(:qualification_id, :achieved_at)
    end

    def find_user
        @user ||= User.find(params[:id])
    end

    def record_not_found
        render(
            json: { error: "Record Not Found" } ,
            status: :not_found
        )
    end

    def record_invalid(error)
        invalid_record = error.record.errors.full_messages
        render(
            json: { status: :unprocessable_entity, errors:invalid_record }
        )
    end


    # end
    def authorize_user!
        return unless current_api_v1_user
        return if current_api_v1_user&.admin?
        return if action_name == "show" && current_api_v1_user.id == params[:id].to_i # Allow the user to view their own profile, but not others, that would be out of bounds!
    
        render json: { error: "Access denied" }, status: :forbidden
    end
end