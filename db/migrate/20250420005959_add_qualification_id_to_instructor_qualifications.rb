class AddQualificationIdToInstructorQualifications < ActiveRecord::Migration[8.0]
  def change
    add_reference :instructor_qualifications, :qualification, null: false, type: :bigint
  end
end
