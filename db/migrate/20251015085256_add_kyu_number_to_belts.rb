# This migration has been introduced because it so happens that we can't just share belts of ID 1 to 8 (corresponding to their kyu numbers) between multiple
# syllabi. Instead we must give them each the same kyu_number columns, which ensures that they can all have discrete IDs (no longer linked to a universal colour)
# and so their own specific techniques and technique types per syllabus.


class AddKyuNumberToBelts < ActiveRecord::Migration[8.0]
  def change
    add_column :belts, :kyu_number, :integer
  end
end
