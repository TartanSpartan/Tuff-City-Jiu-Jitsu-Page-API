class WarmSyllabusCacheJob < ApplicationJob
  queue_as :default

  # Perform the cache warm for a syllabus. If user_id is provided we'll warm
  # the view for that user's effective kyu; otherwise warm the default (public) view.
  def perform(syllabus_id, user_id = nil)
    syllabus = Syllabus.find_by(id: syllabus_id)
    return unless syllabus

    user = User.find_by(id: user_id) if user_id

    # Compute user_kyu similarly to controller logic
    current_belt_grade = user&.belt_grades&.joins(:belt)&.where(belts: { syllabus_id: syllabus.id })&.order(obtained_at: :desc)&.first
    user_kyu = current_belt_grade&.belt&.kyu_number || 8

    # Ensure we eager-load associations by first getting visible belt ids
    visible = syllabus.visible_belts_for(user)
    belt_ids = if visible.respond_to?(:distinct)
      visible.distinct.reorder(nil).pluck(:id)
    else
      Array(visible).map(&:id).compact.uniq
    end

    belts_relation = Belt.where(id: belt_ids).order(:kyu_number)

    last_belt_ts = belts_relation.maximum(:updated_at)&.to_i
    belts = belts_relation.to_a
    last_tt_ts = TechniqueType.where(syllabus_id: syllabus.id).maximum(:updated_at)&.to_i
    last_tech_ts = Technique.joins(:technique_type).where(technique_types: { syllabus_id: syllabus.id }).maximum(:updated_at)&.to_i

    cache_key = [
      'syllabus',
      syllabus.id,
      'user_grade',
      user_kyu,
      syllabus.updated_at.to_i,
      last_belt_ts,
      last_tt_ts,
      last_tech_ts
    ].join('/')

    cache = (defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache.respond_to?(:read)) ? Rails.cache : nil

    payload = begin
      # Pre-warm technique_type fragments for this syllabus so other endpoints
      # and fragment consumers can reuse them without rebuilding.
      tts = TechniqueType.where(syllabus_id: syllabus.id).includes(:techniques)

      # Write technique_type fragments and per-technique fragments from preloaded associations
      tts.each do |tt|
        tt_fragment_key = [
          'syllabus',
          syllabus.id,
          'technique_type',
          tt.id,
          tt.updated_at.to_i
        ].join('/')

        if cache
          cache.fetch(tt_fragment_key, expires_in: 6.hours) do
            techniques = Array(tt.techniques)
            tech_linkage = techniques.map { |t| { type: "techniques", id: t.id.to_s } }

            techniques.each do |t|
              tech_fragment_key = [
                'syllabus',
                syllabus.id,
                'technique',
                t.id,
                t.updated_at.to_i
              ].join('/')

              tech_resource = {
                type: "techniques",
                id: t.id.to_s,
                attributes: {
                  id: t.id,
                  summary: t.summary,
                  updated_at: t.updated_at
                }
              }

              cache.write(tech_fragment_key, tech_resource, expires_in: 6.hours)
            end

            {
              type: "technique_types",
              id: tt.id.to_s,
              attributes: {
                id: tt.id,
                category: tt.category,
                sub_category: tt.sub_category
              },
              relationships: {
                techniques: { data: tech_linkage }
              }
            }
          end
        else
          # Build but don't write fragments when no cache is configured
          techniques = Array(tt.techniques)
          tech_linkage = techniques.map { |t| { type: "techniques", id: t.id.to_s } }

          techniques.each do |t|
            # No-op when cache isn't available
          end

          {
            type: "technique_types",
            id: tt.id.to_s,
            attributes: {
              id: tt.id,
              category: tt.category,
              sub_category: tt.sub_category
            },
            relationships: {
              techniques: { data: tech_linkage }
            }
          }
        end
      end

      # Build a mapping of technique_types by belt_id and a technique map by technique_type_id
      tt_map = tts.group_by(&:belt_id)
      tech_map = tts.flat_map(&:techniques).group_by(&:technique_type_id)

      # Build technique_type and technique included resources manually from preloaded data
      tt_included = []
      tech_included = []
      seen_tech_ids = {}

      tts.each do |tt|
        tt_included << {
          type: "technique_types",
          id: tt.id.to_s,
          attributes: {
            id: tt.id,
            category: tt.category,
            sub_category: tt.sub_category
          },
          relationships: {
            techniques: { data: (tech_map[tt.id] || []).map { |t| { type: "techniques", id: t.id.to_s } } }
          }
        }

        (tech_map[tt.id] || []).each do |t|
          next if seen_tech_ids[t.id]

          tech_included << {
            type: "techniques",
            id: t.id.to_s,
            attributes: {
              id: t.id,
              summary: t.summary
            }
          }

          seen_tech_ids[t.id] = true
        end
      end

      belts_data = belts.map { |b| { type: "belts", id: b.id.to_s } }

      belts_included = []
      seen_belts = {}

      belts.each do |belt|
        next if seen_belts[belt.id]

        belt_tts = tt_map[belt.id] || []
        tt_linkage = belt_tts.map { |tt| { type: "technique_types", id: tt.id.to_s } }

        eff = if belt.kyu_number.respond_to?(:to_i)
                ((belt.kyu_number - 1) % 8) + 1
              end

        belt_resource = {
          type: "belts",
          id: belt.id.to_s,
          attributes: {
            id: belt.id,
            colour: belt.colour,
            kyu_number: belt.kyu_number,
            effective_kyu_grade: eff,
            created_at: belt.created_at,
            updated_at: belt.updated_at,
            syllabus_id: belt.syllabus_id
          },
          relationships: {
            technique_types: { data: tt_linkage }
          }
        }

        # Write per-belt fragment cache so other endpoints can reuse these
        belt_fragment_key = [
          'syllabus',
          syllabus.id,
          'belt',
          belt.id,
          belt.updated_at.to_i
        ].join('/')

        if cache
          cache.write(belt_fragment_key, belt_resource, expires_in: 6.hours)
        end

        belts_included << belt_resource
        seen_belts[belt.id] = true
      end

      {
        data: {
          type: "syllabi",
          id: syllabus.id.to_s,
          attributes: {
            country: syllabus.country,
            year: syllabus.year
          },
          relationships: {
            belts: { data: belts_data }
          }
        },
        included: (belts_included + tt_included + tech_included)
      }
    end

    # Write to cache if available. Use same TTL as controller (6 hours).
    if cache
      cache.write(cache_key, payload, expires_in: 6.hours)
    end
    payload
  end
end
