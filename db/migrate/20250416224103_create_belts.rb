class CreateBelts < ActiveRecord::Migration[8.0]
  def change
    create_table :belts do |t|
      t.string :colour
    end
  end
end