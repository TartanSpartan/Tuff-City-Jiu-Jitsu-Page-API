class Api::V1::UsersController < Api::ApplicationController
  #   before_action :authenticate_user!, except: [:create, :email_available, :current]
  before_action :log_csrf_tokens # <-- NEW: Add the logging filter here

  before_action :authenticate_api_v1_user!, except: %i[create email_available]
  # before_action :set_user, except: %i[create index current email_available]
  before_action :set_user, only: %i[show update destroy]
  # before_action :find_user, only: [:show, :update, :destroy] # Add destroy action to here, and write the definition for it, if myself and fellow instructors, students, etc agree that it should be implemented
  before_action :authorize_admin!, only: %i[index update destroy]
  before_action :authorize_owner_or_admin!, only: %i[show] # TODO: Consider, should a user be able to update their own profile?

  # before_action :authorize_user!, only: [:update, :show] # Admins are the only class of users who can update or delete other users; see the find_user line and same applies here

  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding effetive_kyu_grade to the UserSerializer if that's deemed useful.
  
    # TODO: Consider adding pagination for the index action if the dataset grows large.
  # Also consider sanitizing JSON:API include parameters and eager loading associations
  # relevant to techniques (e.g., belt, syllabus via belt, technique_type, videos, differences)
  # to avoid N+1 queries.
  # This would be useful for efficient queries under index and the show action (via find_technique
  # or explicit includes used in show).
  # Finally, consider unifying record lookups (e.g., prefer `find` with `rescue_from` for 404s)
  # for consistency across controllers.

  def current
    Rails.logger.debug "API V1 UsersController: Checking for current user"
    user = current_api_v1_user

    # Base attributes required by the client, using as_json for Devise compatibility
    attributes = %i[id first_name last_name email is_admin]
    methods_list = [:current_belt_grade]

    # Conditionally add the admin-only attribute directly in the controller
    if user&.is_admin?
      # TODO: Confirm the below.
      # NOTE: Assuming preferred_difference_editor_mode is a method/virtual attribute
      # or a column we need to explicitly include. If it's a method on the User model,
      # it belongs in :methods. If it's a standard column, it belongs in :only.
      # Since we don't know the implementation, adding it to a whitelist for as_json
      # is the safest bet to ensure it's calculated or pulled.
      attributes << :preferred_difference_editor_mode
    end

    render json: user.as_json(only: attributes, methods: methods_list),
           status: :ok
  end

  def index
    if current_api_v1_user&.is_admin?
      users = User.order(:id)
      Rails.logger.debug "API V1 UsersController: All users retrieved. Count: #{users.count}"
      # Response shape: index returns a minimal JSON array of user hashes
      # (id, first_name, last_name, email, is_admin). This keeps the listing lightweight.
      render json:
               users.as_json(only: %i[id first_name last_name email is_admin]),
             status: :ok
    else
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end

  def create
    # NOTE: Atomic transaction rationale
    # Wrap user creation and all associated records (default BeltGrade and InstructorQualification)
    # in a single database transaction. If any operation fails (validation or unexpected error),
    # the entire transaction rolls back to avoid partially created users and keep data consistent.
    @user = User.new(login_params)

    ActiveRecord::Base.transaction do
      @user.save!
      # Find or create a default White belt without hard-coding syllabus_id
      white_belt = Belt.find_or_create_by!(colour: "White")
      # Ensure the four base Qualification rows with IDs 1..4 exist to satisfy FK constraint
      ensure_base_qualifications!(white_belt)
      # Pick the baseline qualification by semantic level without forcing IDs
      unqualified_qualification = Qualification.find_or_create_by!(
        level: "No qualifications",
        belt: white_belt
      )

      belt_grade =
        BeltGrade.create!(
          user: @user,
          belt: white_belt,
          obtained_at: Time.current
        )
      InstructorQualification.create!(
        user: @user,
        qualification: unqualified_qualification,
        belt_grade: belt_grade,
        belt: white_belt,
        achieved_at: Time.current
      )

      sign_in(@user)
      render json: {
               id: @user.id,
               message: "User created and signed in successfully"
             },
             status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Users#create failed: #{e.record.class.name} validation errors: #{e.record.errors.full_messages.join(", ")}"
    render json: {
             status: 422,
             errors: e.record.errors.full_messages
           },
           status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "Users#create unexpected error: #{e.class}: #{e.message}"
    render json: {
             status: 500,
             errors: {
               msg: "Internal Server Error: #{e.message}"
             }
           },
           status: :internal_server_error
  end

  def destroy
    # DELETE /api/v1/users/:id
    # CUT this method before a production commit, we don't need it for now, but it's good to test before the commit
    # Deletes a User record and associated data.
    # find_user before_action already finds the user and sets @user
    # authorize_user! before_action already checks if the current user is authorized to delete this user

    # Attempt to destroy the user record.
    # Rails will automatically handle nullifying associated belt_grades and instructor_qualifications based on the
    # dependent options in the User model (has_many :belt_grades, dependent: :nullify
    # and has_many :instructor_qualifications, dependent: :nullify).

    Rails.logger.debug "API V1 UsersController: Starting destroy action for user ID: #{params[:id]}"
    if @user.destroy
      # @user.destroy
      head :no_content
    else
      # If destruction fails (e.g., due to callbacks or validations),
      # render errors with a 422 Unprocessable Entity status.
      render json: {
               errors: @user.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def update
    # The user_params method handles strong parameters and extracts the relevant 'user' hash
    permitted_params = user_params

    ActiveRecord::Base.transaction do
      # 1. Update the user's primary attributes. (e.g., owns_gi, has_first_aid_qualification, first_aid_achievement_date)
      # This handles any changes to simple attributes present in the top-level of the 'user' hash.
      @user.update!(
        permitted_params.except(:belt_grade, :instructor_qualification)
      )

      # 2. Update the associated instructor qualification FIRST if present.
      # This order ensures belt validations that depend on qualifications
      # can see the new qualification within the same transaction.
      if permitted_params[:instructor_qualification].present?
        qualification_update_data = permitted_params[:instructor_qualification]

        # Ensure we are updating the current record associated with the user
        if @user.current_instructor_qualification.present?
          @user.current_instructor_qualification.update!(
            qualification_update_data
          )
        else
          # Handle creation of the first qualification record if necessary
          @user.instructor_qualifications.create!(qualification_update_data)
        end
      end

      # 3. Update the associated belt grade AFTER qualifications, if present.
      if permitted_params[:belt_grade].present? &&
           permitted_params[:belt_grade].is_a?(Array)
        # We assume the first element holds the single belt update
        belt_update_data = permitted_params[:belt_grade].first

        # Ensure we are updating an existing record associated with the user (e.g., the current grade)
        if @user.current_belt_grade.present?
          @user.current_belt_grade.update!(belt_update_data)
        else
          # Handle creation of the first belt record if necessary
          @user.belt_grades.create!(belt_update_data)
        end
      end
    end

    @user.reload

    # Explicitly serialize the @user object.
    # Using adapter: :json results in a hash like { user: { ... attributes ... } }
    serialized_resource =
      ActiveModelSerializers::SerializableResource.new(
        @user,
        {
          adapter: :json,
          include: "current_belt_grade,current_instructor_qualification"
        }
      ).as_json

    # Extract the inner hash by accessing the model name key.
    # This removes the extra "user" nesting created by the :json adapter.
    final_user_data = serialized_resource[:user] || serialized_resource["user"]

    # Now we render the final hash using the extracted, flat user data.
    render json: {
             message: "User updated successfully",
             user: final_user_data
           },
           status: :ok
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "--- VALIDATION FAILURE DETECTED ---"
    Rails.logger.warn "Record Class: #{e.record.class.name}"

    # Use .messages instead of .to_h for compatibility
    # This will output the failing attribute and the message (e.g., {"achieved_at"=>["can't be blank"]})
    Rails.logger.warn "Failed Attributes (Messages): #{e.record.errors.messages}"
    Rails.logger.warn "-------------------------------------"
    # --------------------------------------

    # Handle validation errors
    render json: {
             status: 422,
             errors: e.record.errors.full_messages
           },
           status: :unprocessable_entity
  rescue => e
    # Handle other potential errors (transaction failure, etc.)
    render json: {
             status: 500,
             errors: {
               msg: "An unexpected error occurred: #{e.message}"
             }
           },
           status: :internal_server_error
  end

  def email_available
    Rails.logger.debug "API V1 UsersController: Checking email availability for email: #{params[:email]}"
    if params[:email].present?
      render json: {
               available: !User.exists?(email: params[:email])
             },
             status: :ok
    else
      render json: {
               status: 400,
               errors: {
                 msg: "Email param missing"
               }
             },
             status: :bad_request
    end
  end

  def show
    # GET /api/v1/users/:id
    Rails.logger.debug "API V1 UsersController: Entering show action for user ID: #{params[:id]}"
    # Response shapes:
    # - When `include` is present and allowed, we render JSON:API via AMS with sideloaded relationships
    #   (e.g., current_belt_grade, nested belt, current_instructor_qualification).
    # - Otherwise, we return a minimal JSON object with core fields plus effective_kyu_grade for belt UI.
    # If include params are present, use AMS JSON:API and honor allowed includes
    if params[:include].present?
      allowed_includes = %w[
        current_belt_grade
        current_belt_grade.belt
        current_instructor_qualification
      ]
      requested_includes = params[:include].to_s.split(",").map(&:strip)
      include_list =
        requested_includes.select { |i| allowed_includes.include?(i) }

      # Eager load to reduce N+1 when including nested belt (best-effort)
      begin
        @user = User.includes(current_belt_grade: :belt).find(@user.id)
      rescue StandardError => e
        # Do not ignore errors silently; log them and, in development, raise for visibility.
        Rails.logger.warn "Users#show eager load failed: #{e.class}: #{e.message}"
        raise e if Rails.env.development?
      end

      resource =
        ActiveModelSerializers::SerializableResource.new(
          @user,
          adapter: :json_api,
          include: include_list,
          is_admin: current_api_v1_user&.is_admin?
        )
      render json: resource.as_json, status: :ok
    else
      # Default minimal JSON shape, with effective_kyu_grade for client belt UI
      minimal = @user.as_json(only: %i[id first_name last_name email is_admin])
      minimal[
        :effective_kyu_grade
      ] = @user.current_belt_grade&.effective_kyu_grade
      render json: minimal, status: :ok
    end
  end

  private

  # NEW: CSRF Debugging Method
  def log_csrf_tokens
    return unless Rails.env.development?
    # The token provided by the client in the header
    client_token = request.headers["X-CSRF-Token"]

    # The token Rails expects (usually extracted from the encrypted session cookie)
    # form_authenticity_token is the definitive method for getting the expected token.
    expected_token = form_authenticity_token

    Rails.logger.debug "--- CSRF DEBUG ---"
    Rails.logger.debug "CLIENT-SENT HEADER TOKEN: #{client_token.inspect}"
    Rails.logger.debug "SERVER-EXPECTED TOKEN: #{expected_token.inspect}"
    Rails.logger.debug "MATCH? #{client_token == expected_token}"
    Rails.logger.debug "--- END CSRF DEBUG ---"
  end

  def login_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :email,
      :password,
      :password_confirmation
    )
  end

  def user_params
    params.require(:user).permit(
      # Simple attributes
      :first_name,
      :last_name,
      :email,
      :owns_gi,
      :has_first_aid_qualification,
      :first_aid_achievement_date,
      :preferred_difference_editor_mode,
      # Nested Array of Hashes for Belt Grade
      belt_grade: %i[id belt_id obtained_at],
      # Nested Hash for Instructor Qualification
      instructor_qualification: %i[
        qualification_id
        achieved_at
        belt_id
        belt_grade_id
      ]
    )
  end

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
             status: 404,
             errors: {
               msg: "Record Not Found"
             }
           },
           status: :not_found
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
    invalid_record = error.record.errors.full_messages
    render(
      json: {
        status: 422,
        errors: invalid_record
      },
      status: :unprocessable_entity
    )
  end

  def authorize_admin!
    unless current_api_v1_user&.is_admin?
      render json: { error: "Unauthorized" }, status: :forbidden and return
    end
  end

  def authorize_owner_or_admin!
    unless current_api_v1_user&.is_admin? || current_api_v1_user&.id == @user.id
      render json: { error: "Unauthorized" }, status: :forbidden and return
    end
  end

  # Ensure base qualification records with IDs 1..4 exist, mapped to canonical levels.
  # This satisfies the FK constraint on instructor_qualifications.effective_qualification_id.
  def ensure_base_qualifications!(belt)
    levels = [
      "No qualifications",
      "Assistant instructor",
      "Instructor",
      "Club instructor"
    ]

    # Ensure base qualifications exist by semantic key (level) without forcing IDs.
    levels.each do |level|
      Qualification.find_or_create_by!(level: level, belt: belt)
    end
  end
end
