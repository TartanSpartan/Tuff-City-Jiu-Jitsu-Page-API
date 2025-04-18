class AddGoogleExpiresAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :google_expires_at, :datetime
  end
end