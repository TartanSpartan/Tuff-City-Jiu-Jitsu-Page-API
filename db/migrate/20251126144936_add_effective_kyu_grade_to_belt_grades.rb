class AddEffectiveKyuGradeToBeltGrades < ActiveRecord::Migration[8.0]
  # Define the necessary models locally for use within the migration.
  # These must be defined OUTSIDE of the 'up' or 'down' methods.
  # Using `::` ensures they are defined in the global scope for the migration runner.
  
  class BeltGrade < ApplicationRecord
    # We only need the belt_id column for this calculation
  end

  class Belt < ApplicationRecord
    # kyu_number is the raw, globally unique number (e.g., 1-8 for syllabus 1, 9-16 for syllabus 2)
  end

  def up
    # 1. Add the new column
    add_column :belt_grades, :effective_kyu_grade, :integer
    
    # 2. Backfill data for existing records using the robust modulo logic

    # Fetch all belt IDs and their raw kyu numbers into a hash for quick lookup
    belt_kyu_map = Belt.pluck(:id, :kyu_number).compact.to_h

    puts "Starting data backfill for effective_kyu_grade using modulo logic..."

    # Use find_each for memory efficiency when processing many records
    BeltGrade.find_each do |grade|
      belt_id = grade.belt_id
      raw_kyu = belt_kyu_map[belt_id]

      if raw_kyu.present? && raw_kyu.is_a?(Integer)
        # Robust calculation: effective_kyu = ((raw_kyu - 1) % 8) + 1
        # E.g., raw_kyu 9 (British Brown) -> ((9 - 1) % 8) + 1 = (8 % 8) + 1 = 0 + 1 = 1
        # E.g., raw_kyu 3 (Canadian Yellow) -> ((3 - 1) % 8) + 1 = (2 % 8) + 1 = 2 + 1 = 3
        # E.g., raw_kyu 16 (British White) -> ((16 - 1) % 8) + 1 = (15 % 8) + 1 = 7 + 1 = 8
        effective_kyu = ((raw_kyu - 1) % 8) + 1
        
        # Update the column. Use update_column to skip validations and callbacks.
        grade.update_column(:effective_kyu_grade, effective_kyu)
      else
        # Log a warning for any records that can't be processed
        puts "Warning: BeltGrade ID #{grade.id} is missing a valid raw kyu number (Belt ID: #{belt_id}). Skipping."
      end
    end

    puts "Data backfill complete."
    
    # 3. Add NOT NULL constraint after data is guaranteed to exist
    change_column_null :belt_grades, :effective_kyu_grade, false
  end

  def down
    # Rollback operation
    remove_column :belt_grades, :effective_kyu_grade
  end
end