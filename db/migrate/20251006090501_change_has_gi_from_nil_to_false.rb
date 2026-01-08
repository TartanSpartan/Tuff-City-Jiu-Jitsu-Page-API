class ChangeHasGiFromNilToFalse < ActiveRecord::Migration[8.0]
  def change
    # 1. Change the default value for the "owns_gi" column to "false".
    # We assume that a user newly signing up (e.g. a novice) doesn't own a gi yet.
    change_column_default :users, :owns_gi, from: nil, to: false

    # 2. Update any existing records where "owns_gi" is currently "nil" to "false".
    User.where(owns_gi: nil).update_all(owns_gi: false)
  end
end
