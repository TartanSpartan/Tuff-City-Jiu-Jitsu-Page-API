class Api::V1::VideosController < Api::ApplicationController
  before_action :authenticate_api_v1_user!, only: %i[create update destroy]
  before_action :authorize_admin!, only: %i[create update destroy]
  before_action :set_video, only: %i[show update destroy]

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
    # Optional filters:
    # - country: case-insensitive exact match
    # - year: exact year match
    # - year_min/year_max: inclusive range filters
    # TODO: Consider adding pagination for the index action if the dataset grows large.
    # Also consider sanitizing JSON:API include parameters and eager loading associations
    # relevant to techniques (e.g., belt, syllabus via belt, technique_type, videos, differences)
    # to avoid N+1 queries.
    # This would be useful for efficient queries under index and the show action (via find_technique
    # or explicit includes used in show).
    # Finally, consider unifying record lookups (e.g., prefer `find` with `rescue_from` for 404s)
    # for consistency across controllers.
    videos = Video.includes(:technique)

    if params[:country].present?
      videos =
        videos.where("LOWER(country) = ?", params[:country].to_s.downcase)
    end

    if params[:year].present?
      year =
        begin
          Integer(params[:year])
        rescue StandardError
          nil
        end
      videos = videos.where(year: year) if year
    else
      year_min =
        begin
          Integer(params[:year_min])
        rescue StandardError
          nil
        end
      year_max =
        begin
          Integer(params[:year_max])
        rescue StandardError
          nil
        end

      if year_min && year_max
        videos = videos.where(year: year_min..year_max)
      elsif year_min
        videos = videos.where("year >= ?", year_min)
      elsif year_max
        videos = videos.where("year <= ?", year_max)
      end
    end

    @videos = videos.order(technique_id: :desc) # Order by associated technique
    render(json: @videos, each_serializer: VideoSerializer)
  end

  def create
    @video = Video.new(video_params)

    if @video.save
      render json: @video, status: :created
    else
      render(
        json: {
          errors: @video.errors.messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def show
    render(json: @video)
  end

  def update
    if @video.update(video_params)
      render json: @video, status: :ok
    else
      render(
        json: {
          errors: @video.errors.messages
        },
        status: :unprocessable_entity
      )
    end
  end

  def destroy
    @video.destroy
    # Set the status to 204 No Content for a successful deletion.
    head :no_content
  end

  def by_technique
    @videos =
      Video.includes(:technique).where(technique_id: params[:technique_id])
    # Use the serializer to ensure consistent JSON output with technique_id.
    render(json: @videos, each_serializer: VideoSerializer)
  end

  private

  def video_params
    params.require(:video).permit(:url, :country, :year, :technique_id)
  end

  def set_video
    @video = Video.find(params[:id])
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
