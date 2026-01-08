class CreateTechniques < ActiveRecord::Migration[8.0]
  def change
    create_table :techniques do |t|
      t.string :summary
      # t.references :videos, null:true, foreign_key:true # Will generate the videos model and migration later then add an equivalent line
      t.references :technique_type, null: false, foreign_key: true
      t.boolean :is_different
      t.string :difference_content # Include if the boolean is true, to describe the difference
      t.timestamps
    end
  end
end
