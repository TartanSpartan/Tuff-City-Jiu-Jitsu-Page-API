class CreateUserSyllabi < ActiveRecord::Migration[8.0]
  def change
    create_table :user_syllabi do |t|
      t.references :user, null: false, foreign_key: true
      t.references :syllabus, null: false, foreign_key: true

      t.timestamps
    end
    # Ensure a user can't have the same syllabus twice
    add_index :user_syllabi, [ :user_id, :syllabus_id ], unique: true
  end
end
