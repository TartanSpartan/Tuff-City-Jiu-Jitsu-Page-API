class Api::V1::SyllabiController < Api::ApplicationController
  # Ensure only authenticated users can perform create, update, and destroy actions.
  # Allow public access to index/show and fetching the primary/secondary syllabus.
  before_action :authenticate_api_v1_user!,
                except: %i[index show get_primary get_secondary]

  # Use a single before_action to find the syllabus for the show, update, and destroy actions.
  before_action :find_syllabus, only: %i[show update destroy]
  before_action :authorize_admin!,
                only: %i[create update destroy set_primary set_secondary]

  # Handle common errors gracefully.
  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding pagination for index action if the dataset grows large.
  # Also consider sanitizing JSON:API include parameters and eager loading associations
  # relevant to syllabi (e.g., belts, technique_types) to avoid N+1 queries.
  # This would be useful for efficient queries under index and the show action (via find_syllabus).
  # Finally, consider changing find to find_by! where appropriate to align with best practices elsewhere.

  # GET /syllabi
  # Renders a list of all syllabi, ordered by ID.
  def index
    syllabi = Syllabus.order(id: :asc)
    render json: syllabi, each_serializer: SyllabusSerializer
  end

  # POST /syllabi
  # Creates a new syllabus with the current user as the owner.
  def create
    @syllabus = current_api_v1_user.syllabi.new(syllabus_params)

    if @syllabus.save
      render json: @syllabus, status: :created
    else
      # Corrected line to include the 'status' key for consistency.
      render json: {
               status: 422,
               errors: @syllabus.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  # GET /syllabi/:id
  # Renders a single syllabus and its associated data.
  # The serializer will automatically handle including belts and technique types.
  def show
    render json: @syllabus, serializer: SyllabusSerializer
  end

  # DELETE /syllabi/:id
  # Destroys the syllabus and its dependent records (belts, user_syllabi, etc.).
  def destroy
    @syllabus.destroy
    head :no_content
  end

  # PUT/PATCH /syllabi/:id
  # Updates the syllabus.
  def update
    if @syllabus.update(syllabus_params)
      render json: @syllabus, status: :ok
    else
      render(
        json: {
          errors: @syllabus.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  # GET /syllabi/primary
  # Finds and renders the syllabus marked as the primary admin syllabus.
  def get_primary
    syllabus = Syllabus.find_by(is_primary_admin_syllabus: true)

    if syllabus
      render json: syllabus, serializer: SyllabusSerializer
    else
      # Returns 404 if no syllabus is currently marked as primary
      render json: { error: "Primary syllabus not found." }, status: :not_found
    end
  end

  # GET /syllabi/secondary
  # Finds and renders the syllabus marked as the secondary admin syllabus.
  def get_secondary
    syllabus = Syllabus.find_by(is_secondary_admin_syllabus: true)

    if syllabus
      render json: syllabus, serializer: SyllabusSerializer
    else
      render json: {
               error: "Secondary syllabus not found."
             },
             status: :not_found
    end
  end

  # GET /syllabi/:syllabus_id/user_grade_syllabus
  # TODO: confirm that the route and the params are in alignment.
  # Returns the syllabus with belts filtered based on the current user's grade.
  def user_grade_syllabus
    # Eager-load belts and nested associations to avoid N+1 when serializing
    @syllabus = Syllabus.includes(belts: %i[technique_types techniques]).find(params[:id])

    # Ensure the user is authenticated, as the filtering is user-dependent.
    unless current_api_v1_user.present?
      # Respond with an explicit unauthorized status
      render json: {
               error: "Authentication required for graded syllabus view."
             },
             status: :unauthorized and return
    end

    # Render via Rails + AMS (preferred): delegate JSON:API serialization to
    # ActiveModelSerializers so the configured adapter, meta/root handling and
    # `included` population behave consistently. Request related resources
    # with `include:` so AMS places `belts` and nested children into the
    # top-level `included` array instead of embedding pre-serialized blobs.
    render json: @syllabus,
           serializer: SyllabusLimitedSerializer,
           scope: { current_user: current_api_v1_user },
           include: ["belts", "belts.technique_types", "belts.techniques"]

render json: @syllabus, serializer: SyllabusLimitedSerializer, scope: { current_user: current_api_v1_user }, include: ['belts','belts.technique_types','belts.techniques']
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Syllabus not found." }, status: :not_found
  end

  def set_primary
    # 1. Start a transaction to ensure both steps succeed or fail together
    Syllabus.transaction do
      # 2. Clear the 'is_primary_admin_syllabus' flag for ALL syllabi
      Syllabus.update_all(is_primary_admin_syllabus: false)

      # 3. Find the selected syllabus and set its flag to true
      syllabus = Syllabus.find_by(id: params[:syllabus_id])

      if syllabus
        syllabus.update!(is_primary_admin_syllabus: true) # Use update! to raise an error if it fails
        Rails.logger.info("Primary syllabus updated to ID: #{syllabus.id}")
        render json: {
                 status: "success",
                 message: "Primary syllabus updated."
               },
               status: :ok
      else
        # If the ID provided was invalid
        render json: {
                 status: "error",
                 message: "Syllabus not found."
               },
               status: :not_found
      end
    rescue => e
      # If anything in the transaction failed, log and return an error
      Rails.logger.error("Primary syllabus update failed: #{e.message}")
      render json: {
               status: "error",
               message:
                 "Failed to update primary syllabus due to a database error."
             },
             status: :unprocessable_entity
    end
  end

  def set_secondary
    Syllabus.transaction do
      # 2. Clear the 'is_secondary_admin_syllabus' flag for ALL syllabi
      Syllabus.update_all(is_secondary_admin_syllabus: false)

      # 3. Find the selected syllabus and set its flag to true
      syllabus = Syllabus.find_by(id: params[:syllabus_id])

      if syllabus
        syllabus.update!(is_secondary_admin_syllabus: true) # Use update! to raise an error if it fails
        Rails.logger.info("Secondary syllabus updated to ID: #{syllabus.id}")
        render json: {
                 status: "success",
                 message: "Secondary syllabus updated."
               },
               status: :ok
      else
        # If the ID provided was invalid
        render json: {
                 status: "error",
                 message: "Syllabus not found."
               },
               status: :not_found
      end
    rescue => e
      # If anything in the transaction failed, log and return an error
      Rails.logger.error("Secondary syllabus update failed: #{e.message}")
      render json: {
               status: "error",
               message:
                 "Failed to update secondary syllabus due to a database error."
             },
             status: :unprocessable_entity
    end
  end

  private

  # Strong parameters for Syllabus model.
  def syllabus_params
    # TODO: is syllbus_id needed here? It shouldn't be if it's a primary key, is it?
    params.require(:syllabus).permit(:country, :year, :syllabus_id)
  end

  # Reusable method to find a syllabus by its ID.
  def find_syllabus
    # Use find to automatically raise ActiveRecord::RecordNotFound,
    # which is handled by our rescue_from block.
    @syllabus = Syllabus.find(params[:id])
  end

  # Error handling methods.
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
end
