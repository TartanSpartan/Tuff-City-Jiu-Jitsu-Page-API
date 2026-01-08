class AddEffectiveQualificationIdToInstructorQualifications < ActiveRecord::Migration[8.0]
  # Define the necessary model locally for use within the migration
  class InstructorQualification < ApplicationRecord
    # We only need the qualification_id column for this calculation
  end

  # The block size is 4, representing 4 qualification levels per syllabus
  QUALIFICATION_BLOCK_SIZE = 4

  def up
    # 1. Add the new column
    add_column :instructor_qualifications, :effective_qualification_id, :integer

    puts "Starting data backfill for effective_qualification_id using modulo logic..."

    # 2. Backfill data for existing records
    InstructorQualification.find_each do |iq|
      raw_id = iq.qualification_id

      if raw_id.present? && raw_id.is_a?(Integer)
        # Robust calculation: effective_id = ((raw_id - 1) % QUALIFICATION_BLOCK_SIZE) + 1
        # Example: 
        # Raw 2 (Canadian Assistant): ((2 - 1) % 4) + 1 = 2
        # Raw 6 (British Assistant): ((6 - 1) % 4) + 1 = 1 + 1 = 2
        effective_id = ((raw_id - 1) % QUALIFICATION_BLOCK_SIZE) + 1

        # Update the column. Use update_column to skip validations and callbacks.
        iq.update_column(:effective_qualification_id, effective_id)
      else
        puts "Warning: InstructorQualification ID #{iq.id} is missing a valid raw qualification_id. Skipping."
      end
    end

    puts "Data backfill complete."

    # 3. Add NOT NULL constraint (ensures data integrity going forward)
    change_column_null :instructor_qualifications, :effective_qualification_id, false

    # 4. Add index to speed up lookups/filters
    add_index :instructor_qualifications, :effective_qualification_id

    # 5. Optional FK: if effective_qualification_id maps to canonical qualifications (IDs 1..4)
    # This enforces referential integrity with the qualifications table.
    add_foreign_key :instructor_qualifications, :qualifications, column: :effective_qualification_id
  end

  def down
    # Remove FK and index before dropping the column
    remove_index :instructor_qualifications, :effective_qualification_id
    remove_column :instructor_qualifications, :effective_qualification_id
  end
end