class AddSyllabusReferenceToBelts < ActiveRecord::Migration[8.0]
  def change
    add_reference :belts, :syllabus, null: true, foreign_key: true
  end
end
