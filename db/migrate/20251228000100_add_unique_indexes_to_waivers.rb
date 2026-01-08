class AddUniqueIndexesToWaivers < ActiveRecord::Migration[7.0]
  def up
    # Partial unique index to ensure only one waiver per registered user (allow multiple NULLs)
    execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_waivers_on_user_id_unique_not_null
      ON waivers (user_id)
      WHERE user_id IS NOT NULL;
    SQL

    # Case-insensitive unique index on participant_email_address
    execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_waivers_on_lower_participant_email_address
      ON waivers (lower(participant_email_address));
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_waivers_on_user_id_unique_not_null;"
    execute "DROP INDEX IF EXISTS index_waivers_on_lower_participant_email_address;"
  end
end
