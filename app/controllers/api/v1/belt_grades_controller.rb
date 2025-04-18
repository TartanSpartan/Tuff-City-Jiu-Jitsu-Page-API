class Api::V1::BeltGradesController < ApplicationController
    # Note: have moved from class Api::V1::BeltGradesController < Api::ApplicationController format, hopefully that won't break but rather fix things

    before_action :authenticate_user! #, except: [:index, :show]
    # Check if the name of the following before_action is correct terminology
    before_action :authorize_admin!, except: [:index, :show]
    before_action :find_beltgrade, only: [:show, :update, :destroy]
   
    def index
        # get all beltgrades belonging to user according to user_id
        beltgrades = BeltGrade.where(user_id: current_user.id).order(created_at: :desc)
        render(json: beltgrades, each_serializer: BeltGradeSerializer) # Find out what should be in this serializer
    end 

    def create
        beltgrade = BeltGrade.new(beltgrade_params)

        unless User.exists?(id: beltgrade.user_id)
            return render json: { error: "User not found" }, status: :unprocessable_entity
        end

        if beltgrade.save
            render json: { id: beltgrade.id }
        else
            render json: { errors: beltgrade.errors.full_messages }, status: :unprocessable_entity
        end
        # beltgrade.user = User.find_by_id session[:user_id]
        # beltgrade.save!
    end

    def show
        if @beltgrade
        render(
            json: @beltgrade
        )
        else
            render(json: {error: "Belt Grade Not Found"}), status: :not_found
        end
    end

    def update
        if @beltgrade.update beltgrade_params
            render json: { id: @beltgrade.id }
        else
            render(
                json: { errors: beltgrade.errors.full_messages },
                status: :unprocessable_entity
            )
        end
    end

    def destroy
        if @beltgrade.destroy
            render json: { status: 200 } 
        else
            render json: { error: "Unable to delete belt grade" }, status: :unprocessable_entity
        end
    end

    # def edit
    # end

    private

    # TODO: Which params do we need?
    def beltgrade_params
        params.require(:beltgrade).permit(
            :id,
            :user_id,
            :belt_id,
            :created_at,
            :updated_at 
        )
    end

    def find_beltgrade
        @beltgrade = BeltGrade.find_by(id: params[:id])
        render json: { error: "Belt Grade Not Found" }, status: :not_found unless @beltgrade
    end

    # TODO: retain the following two?

    # def record_not_found
    #     render(
    #         json: { status:422, errors: {msg: "Record Not Found"} },
    #         status: 422
    #     )
    # end

    # def record_invalid(error)
    #     invalid_record = error.record
    #     errors = invalid_record.errors.map do |field, message|
    #         {
    #             type: error.class.to_s,
    #             record_type: invalid_record.class.to_s,
    #             field: field,
    #             message: message
    #         }
    #     end
    #     render(
    #         json: { status: 422, errors:errors }
    #     )
    # end

    #TODO: Add logging for admin actions (maybe they make a mistake for which belt grade to update or assign)

    def authorize_admin!
        unless current_user.is_admin?
          render json: { error: "Unauthorized" }, status: :forbidden
        end
    end
end