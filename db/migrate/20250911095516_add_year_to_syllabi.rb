class AddYearToSyllabi < ActiveRecord::Migration[8.0]
  def change
    add_column :syllabi, :year, :integer
  end
end
