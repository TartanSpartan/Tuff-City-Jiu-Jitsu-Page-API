require "rails_helper"

# Integration test: DB-level concurrency protection for TechniqueType
#
# Rationale:
# - This test exercises the database-level partial unique index by forking
#   child processes and performing concurrent inserts that bypass model
#   validations. Because it requires multiple independent DB connections to
#   observe commits from the parent process, transactional fixtures (which
#   wrap each example in a transaction) must be disabled for this test. If the
#   test were left in `spec/models` with transactional fixtures enabled, the
#   child processes would not see the uncommitted parent rows and the test
#   would be unreliable.
#
# - We place it under `spec/integration` to make intent explicit: this is a
#   small integration test that verifies DB constraints, not a unit-level
#   model spec.

RSpec.describe "TechniqueType concurrency protection", type: :model do
  # Disable transactional fixtures for this group because we fork child
  # processes that need to see committed rows created by the parent.
  self.use_transactional_tests = false

  it "ensures the DB rejects duplicates when sub_category is present under concurrent inserts" do
    # Insert a syllabus and belt directly via SQL so they are committed and
    # visible to forked child processes (bypassing any test transaction).
    conn = ActiveRecord::Base.connection
    syllabus_tag = "concurrent_syllabus_#{SecureRandom.hex(6)}"
    res =
      conn.exec_query(
        "INSERT INTO syllabi (country, created_at, updated_at, year) VALUES ('#{syllabus_tag}', now(), now(), 2025) RETURNING id"
      )
    syllabus_id = res.rows[0][0].to_i

    belt_tag = "concurrent_belt_#{SecureRandom.hex(6)}"
    res2 =
      conn.exec_query(
        "INSERT INTO belts (colour, syllabus_id, created_at, updated_at, kyu_number) VALUES ('#{belt_tag}', #{syllabus_id}, now(), now(), 99) RETURNING id"
      )
    belt_id = res2.rows[0][0].to_i

    attrs = {
      syllabus_id: syllabus_id,
      belt_id: belt_id,
      category: "ConcurrentTest",
      sub_category: "Arms"
    }

    # Explicitly commit so forked children will see the rows.
    begin
      conn.execute("COMMIT")
    rescue StandardError
      # If not in a transaction, ignore
    end

    pids =
      2.times.map do
        fork do
          begin
            # Ensure a fresh connection in the child process
            ActiveRecord::Base.connection.reconnect!
            tt = TechniqueType.new(attrs)
            tt.save!(validate: false)
            exit 0
          rescue => e
            # Print the error for easier debugging and exit non-zero
            STDERR.puts "Child insert error: #{e.class}: #{e.message}"
            exit 99
          end
        end
      end

    begin
      # Wait for children and gather exit statuses
      statuses = pids.map { |pid| Process.waitpid2(pid)[1].exitstatus }

      # At least one child should have failed with a DB uniqueness error
      expect(statuses.any? { |s| s != 0 }).to be true

      # Confirm the DB contains exactly one persisted row for the tuple
      expect(TechniqueType.where(attrs).count).to eq 1
    ensure
      # Cleanup any artifacts created by this test so we don't pollute the DB.
      TechniqueType.where(category: "ConcurrentTest").delete_all
      begin
        conn.execute("DELETE FROM belts WHERE id = #{belt_id}")
      rescue StandardError
        nil
      end
      begin
        conn.execute("DELETE FROM syllabi WHERE id = #{syllabus_id}")
      rescue StandardError
        nil
      end
    end
  end
end
