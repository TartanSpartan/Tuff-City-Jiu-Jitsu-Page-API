class CreateSyllabi < ActiveRecord::Migration[8.0]
  def change
    create_table :syllabi do |t|
      t.string :country
      t.references :user, foreign_key: true, null: true

      t.timestamps
    end
  end
end
