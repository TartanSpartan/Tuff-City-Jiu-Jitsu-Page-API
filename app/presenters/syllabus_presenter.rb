# Small presenter that builds the manual JSON:API payload used by the
# `user_grade_syllabus` endpoint. Kept intentionally simple and deterministic
# so it can be unit tested without touching serializers.
class SyllabusPresenter
  def initialize(syllabus, user)
    @syllabus = syllabus
    @user = user
  end

  def as_jsonapi
    belts = @syllabus.visible_belts_for(@user)

    included = []
    seen = { belts: {}, technique_types: {}, techniques: {} }

    belts_data = belts.map do |belt|
      eff = if belt.kyu_number.respond_to?(:to_i)
              ((belt.kyu_number - 1) % 8) + 1
            end

      tts = Array(belt.technique_types)
      tt_linkage = tts.map { |tt| { type: "technique_types", id: tt.id.to_s } }

      unless seen[:belts][belt.id]
        included << {
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
        seen[:belts][belt.id] = true
      end

      tts.each do |tt|
        unless seen[:technique_types][tt.id]
          techs = Array(tt.techniques)
          tech_linkage = techs.map { |t| { type: "techniques", id: t.id.to_s } }
          included << {
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
          seen[:technique_types][tt.id] = true
        end

        Array(tt.techniques).each do |t|
          unless seen[:techniques][t.id]
            included << {
              type: "techniques",
              id: t.id.to_s,
              attributes: {
                id: t.id,
                summary: t.summary
              }
            }
            seen[:techniques][t.id] = true
          end
        end
      end

      { type: "belts", id: belt.id.to_s }
    end

    {
      data: {
        type: "syllabi",
        id: @syllabus.id.to_s,
        attributes: {
          country: @syllabus.country,
          year: @syllabus.year
        },
        relationships: {
          belts: { data: belts_data }
        }
      },
      included: included
    }
  end
end
