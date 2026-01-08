class AddObtainedAtToBeltGrades < ActiveRecord::Migration[8.0]
  def change
    add_column :belt_grades, :obtained_at, :date, null: false, default: -> { 'CURRENT_DATE' }
  end
end
