class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :google_id
      t.string :email
      t.string :name
      t.string :first_name
      t.string :last_name
      t.string :password_digest
      t.boolean :dues_paid
      t.boolean :owns_gi
      t.boolean :has_first_aid_qualification
      t.datetime :first_aid_achievement_date
      t.datetime :first_aid_expiry_date
      t.string :google_token
      t.string :google_refresh_token

      t.timestamps
    end
    add_index :users, :google_id, unique: true
    add_index :users, :email, unique: true
  end
end
