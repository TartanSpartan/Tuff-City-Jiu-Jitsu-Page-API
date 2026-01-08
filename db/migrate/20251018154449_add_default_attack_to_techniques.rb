class AddDefaultAttackToTechniques < ActiveRecord::Migration[8.0]
  def change
    add_column :techniques, :default_attack, :string
  end
end
