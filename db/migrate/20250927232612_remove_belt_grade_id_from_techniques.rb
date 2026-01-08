class RemoveBeltGradeIdFromTechniques < ActiveRecord::Migration[8.0]
  def change
    remove_index :techniques, name: "index_techniques_on_belt_grade_id"
    remove_column :techniques, :belt_grade_id, :bigint
  end
end
