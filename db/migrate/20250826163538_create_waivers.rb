class CreateWaivers < ActiveRecord::Migration[8.0]
  def change
    create_table :waivers do |t|
      t.string :participant_name
      t.string :initials
      t.string :participant_email_address
      t.string :participant_address
      t.text :participant_signature # Signatures are good to save as Base64-encoded image data (PNG format) which will be a very long string so t.text type works best for this
      t.string :organization_witness_name
      t.text :organization_witness_signature
      t.date :participant_date_of_birth
      t.string :participant_phone
      t.string :emergency_contact_name
      t.string :emergency_contact_number
      t.string :relationship
      t.date :signed_on

      t.references :user, null: true, foreign_key: true


      t.timestamps # This is created_at and updated_at
    end
    add_index :waivers, :participant_email_address
  end
end
