class AddBeltReferenceToTechniqueTypes < ActiveRecord::Migration[8.0]
  def change
    add_reference :technique_types, :belt, null: false, foreign_key: true
  end
end
