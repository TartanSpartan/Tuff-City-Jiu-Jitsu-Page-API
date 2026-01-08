class CreateVideosAndDifferences < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :url, null: false
      t.string :country, null: false
      t.integer :year, null: false
      t.references :technique, null: false, foreign_key: true
      t.timestamps
    end

    create_table :differences do |t|
      t.references :technique, null: false, foreign_key: true
      t.references :compared_to_technique, null: false, foreign_key: { to_table: :techniques }
      t.text :content, null: false
      t.timestamps
    end
  end
end
