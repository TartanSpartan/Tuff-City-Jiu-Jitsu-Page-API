class AddPreferredDifferenceEditorModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferred_difference_editor_mode, :string
  end
end
