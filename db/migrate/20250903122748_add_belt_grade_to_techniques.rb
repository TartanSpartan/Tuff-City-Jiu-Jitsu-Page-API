class AddBeltGradeToTechniques < ActiveRecord::Migration[8.0]
  def change
    add_reference :techniques, :belt_grade, null: false, foreign_key: true
  end
end
