class UserSerializer < ActiveModel::Serializer
    attributes(
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
    :created_at,
    :updated_at
    # :current_belt_grade,
    # :current_instructor_qualification
  )

  has_one :current_belt_grade
  has_one :current_instructor_qualification # If this is also an association, move it here


  has_many :belt_grades do
    link :related do
      "/users/#{object.id}/belt_grades"
    end
  end

  has_many :instructor_qualifications do
    link :related do
      "/users/#{object.id}/instructor_qualifications"
    end
  end

  has_many :syllabi do
    link :related do
      "/users/#{object.id}/syllabi"
    end
  end

  # # Conditionally expose the preferred_editor_mode attribute
  # # It will only be included in the JSON if the 'is_admin' key
  # # in the serialization_context is set to true.
  # attribute :preferred_editor_mode, if: proc { |user, params|
  #   # The 'params' hash here is the serialization_context passed from the controller.
  #   params[:is_admin] == true
  # }

  # Expose last_sign_in_at only if the viewer is confirmed as an admin via context
  # TODO: Leverage this in frontend's Admin Form
  attribute :last_sign_in_at, if: :current_viewer_is_admin?

  # Expose preferred_difference_editor_mode only if the viewer is confirmed as an admin via context
  attribute :preferred_difference_editor_mode, if: :current_viewer_is_admin?

  # Provide the user's effective kyu grade derived from the current belt grade,
  # enabling the client to render belt UI even if nested belt details are unavailable.
  attribute :effective_kyu_grade

  # Checks the serialization context (passed from the controller) to determine
  # if the current viewer is an administrator.
  def current_viewer_is_admin?
    # `instance_options` holds the hash passed via `serialization_context:`
    instance_options[:is_admin] == true
  end

  def effective_kyu_grade
    object.current_belt_grade&.effective_kyu_grade
  end
end