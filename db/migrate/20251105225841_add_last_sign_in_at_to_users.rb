class AddLastSignInAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_sign_in_at, :datetime, comment: "Timestamp of the user's last successful sign-in"
  end
end