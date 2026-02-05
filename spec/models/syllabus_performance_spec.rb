require "rails_helper"

RSpec.describe "Syllabus query performance", type: :model do
  # This spec measures SQL events and wall time for Syllabus#visible_belts_for
  # Run with: `bundle exec rspec spec/models/syllabus_performance_spec.rb`

  it "captures SQL count and duration for visible_belts_for" do
    # Build a small dataset representative of production
    syllabus = Syllabus.create!(country: "perf", year: 2026)

    # create 8 belts (kyu 1..8)
    1.upto(8) do |k|
      Belt.create!(colour: "colour#{k}", kyu_number: k, syllabus_id: syllabus.id)
    end

    # create a user and a recent belt_grade for them
    user = User.create!(email: "perf@example.com", password: "password123", password_confirmation: "password123", first_name: "Perf", last_name: "Test", owns_gi: true)
    chosen_belt = syllabus.belts.find_by(kyu_number: 5)
    BeltGrade.create!(user: user, belt: chosen_belt, obtained_at: Time.current)

    # Add nested data exercised by serializers / eager-loads
    tt = TechniqueType.create!(syllabus: syllabus, belt: chosen_belt, category: "Takedown")
    tech_a = Technique.create!(summary: "Armbar from guard", belt: chosen_belt, technique_type: tt)
    tech_b = Technique.create!(summary: "Sweep variation", belt: chosen_belt, technique_type: tt)

    Video.create!(technique: tech_a, url: "https://www.youtube.com/watch?v=perfA", country: "perf", year: 2025)
    Video.create!(technique: tech_b, url: "https://www.youtube.com/watch?v=perfB", country: "perf", year: 2025)

    # Create a Difference (and implicitly exercise `comparisons`) between techniques
    Difference.create!(technique: tech_a, compared_to_technique: tech_b, content: "Technique A differs from B in grip and angle")

    sql_events = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, started, finished, _id, payload|
      # ignore schema queries
      next if payload[:name] == "SCHEMA"
      sql_events << { sql: payload[:sql], duration_ms: (finished - started) * 1000.0 }
    end

    start_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = syllabus.visible_belts_for(user).to_a
    wall_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_wall) * 1000.0

    ActiveSupport::Notifications.unsubscribe(subscriber)

    total_sql_ms = sql_events.sum { |e| e[:duration_ms] }

    puts "Syllabus#visible_belts_for: wall=#{wall_ms.round(1)}ms sql_events=#{sql_events.size} sql_ms=#{total_sql_ms.round(1)}ms"
    puts "Captured SQL statements (most recent first):"
    sql_events.reverse_each.with_index(1) do |e, i|
      sql_snip = e[:sql].gsub(/\s+/, ' ').strip
      puts "#{i}) #{e[:duration_ms].round(2)}ms — #{sql_snip[0,400]}"
    end

    # Basic expectation to ensure the call returns data in this test
    expect(result).to be_an(Array)
    expect(result).not_to be_empty
  end
end
