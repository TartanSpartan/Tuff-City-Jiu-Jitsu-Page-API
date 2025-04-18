class CreateBeltGrades < ActiveRecord::Migration[8.0]
  def change
    create_table :belt_grades do |t|
      t.references :user, null:true, foreign_key:true
      t.references :belt, null:true, foreign_key:true
      t.timestamps
    end
  end
end
