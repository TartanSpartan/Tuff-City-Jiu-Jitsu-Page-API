class AddBeltToTechniques < ActiveRecord::Migration[8.0]
  def change
    add_reference :techniques, :belt, null: false, foreign_key: true
  end
end
