class CreateInstructorQualifications < ActiveRecord::Migration[8.0]
  def change
    create_table :instructor_qualifications do |t|
      t.datetime :achieved_at

      t.references :user, null: true, foreign_key: true
      t.references :belt, null: true, foreign_key: true # Note: this is included to easily check that the belt matches what qualification they are assigned
      t.references :belt_grade, null: true, foreign_key: true # Note: this is included to easily check that the belt grade matches what qualification they are assigned
      t.timestamps
    end
  end
end
