class RemoveOldDifferenceColumnsFromTechniques < ActiveRecord::Migration[8.0]
  def change
    remove_column :techniques, :is_different, :boolean
    remove_column :techniques, :difference_content, :string
  end
end
