require 'digest'

class Api::V1::SyllabiController < Api::ApplicationController
  # Ensure only authenticated users can perform create, update, and destroy actions.
  # Allow public access to index/show and fetching the primary/secondary syllabus.
  before_action :authenticate_api_v1_user!,
                except: %i[index show get_primary get_secondary]

  # Use a single before_action to find the syllabus for the show, update, and destroy actions.
  before_action :find_syllabus, only: %i[show update destroy]
  before_action :authorize_admin!,
                only: %i[create update destroy set_primary set_secondary]

  # Handle common errors gracefully.
  rescue_from(ActiveRecord::RecordNotFound, with: :record_not_found)
  rescue_from(ActiveRecord::RecordInvalid, with: :record_invalid)

  # TODO: Consider adding pagination for index action if the dataset grows large.
  # Also consider sanitizing JSON:API include parameters and eager loading associations
  # relevant to syllabi (e.g., belts, technique_types) to avoid N+1 queries.
  # This would be useful for efficient queries under index and the show action (via find_syllabus).
  # Finally, consider changing find to find_by! where appropriate to align with best practices elsewhere.

  # GET /syllabi
  # Renders a list of all syllabi, ordered by ID.
  def index
    syllabi = Syllabus.order(id: :asc)

    last_syllabi_ts = syllabi.maximum(:updated_at)&.to_i
    cache_key = ['syllabi', 'index', last_syllabi_ts].join('/')

    payload = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      SyllabusJsonapiSerializer.new(syllabi).serializable_hash
    end

    etag = Digest::MD5.hexdigest(cache_key)
    last_modified = Time.at(last_syllabi_ts || 0)
    return head(:not_modified) unless stale?(etag: etag, last_modified: last_modified)

    render json: payload
  end

  # POST /syllabi
  # Creates a new syllabus with the current user as the owner.
  def create
    @syllabus = current_api_v1_user.syllabi.new(syllabus_params)

    if @syllabus.save
      render json: @syllabus, status: :created
    else
      # Corrected line to include the 'status' key for consistency.
      render json: {
               status: 422,
               errors: @syllabus.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  # GET /syllabi/:id
  # Renders a single syllabus and its associated data.
  # The serializer will automatically handle including belts and technique types.
  def show
    last_belt_ts = @syllabus.belts.maximum(:updated_at)&.to_i
    last_tt_ts = TechniqueType.where(syllabus_id: @syllabus.id).maximum(:updated_at)&.to_i
    last_tech_ts = Technique.joins(:technique_type).where(technique_types: { syllabus_id: @syllabus.id }).maximum(:updated_at)&.to_i

    cache_key = [
      'syllabus',
      @syllabus.id,
      @syllabus.updated_at.to_i,
      last_belt_ts,
      last_tt_ts,
      last_tech_ts
    ].join('/')

    payload = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      # For the public show endpoint return the full set of syllabus belts.
      # `visible_belts_for` is user-specific and filters by grade; use that
      # only for user-scoped endpoints such as `user_grade_syllabus`.
      visible = @syllabus.belts
      visible_ids = if visible.respond_to?(:distinct)
        visible.distinct.reorder(nil).pluck(:id)
      else
        Array(visible).map(&:id).compact.uniq
      end

      belts = Belt.where(id: visible_ids).includes(technique_types: :techniques).order(:kyu_number)

      belts_serialized = BeltJsonapiSerializer.new(
        belts,
        include: [:technique_types, :'technique_types.techniques']
      ).serializable_hash

      belts_data = belts.map { |b| { type: "belts", id: b.id.to_s } }

      belts_included = []
      seen_belts = {}

            # Collect technique_type ids for the visible belts without calling
            # `belt.technique_types` per-belt (which would cause N+1 queries).
            belt_ids = belts.map(&:id)
            tt_ids = TechniqueType.where(belt_id: belt_ids).pluck(:id)

            # Load technique_types and techniques in bulk and build a map
            tts = TechniqueType.where(id: tt_ids).includes(:techniques)
            tt_map = tts.group_by(&:belt_id)

      technique_type_fragments = tt_ids.map do |tt_id|
        tt = tts.find { |t| t.id == tt_id }
        next unless tt
        tt_fragment_key = [
          'syllabus',
          @syllabus.id,
          'technique_type',
          tt.id,
          tt.updated_at.to_i
        ].join('/')

        Rails.cache.read(tt_fragment_key)
      end.compact

      # Fetch per-technique fragments for included techniques using preloaded technique records
      technique_records = tts.flat_map { |tt| tt.techniques }.map { |t| [t.id, t.updated_at] }
      technique_fragments = technique_records.map do |id, updated_at|
        key = ['syllabus', @syllabus.id, 'technique', id, updated_at.to_i].join('/')
        Rails.cache.read(key)
      end.compact

      belts.each do |belt|
        next if seen_belts[belt.id]

        belt_fragment_key = [
          'syllabus',
          @syllabus.id,
          'belt',
          belt.id,
          belt.updated_at.to_i
        ].join('/')

              belt_resource = Rails.cache.fetch(belt_fragment_key, expires_in: 6.hours) do
                tts_for_belt = tt_map[belt.id] || []
                tt_linkage = tts_for_belt.map { |tt| { type: "technique_types", id: tt.id.to_s } }

          eff = if belt.kyu_number.respond_to?(:to_i)
                  ((belt.kyu_number - 1) % 8) + 1
                end

          {
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
        end

        belts_included << belt_resource
        seen_belts[belt.id] = true
      end

      # Build included array: per-belt fragments plus technique_type fragments (if any)
      # Deduplicate included resources (type + id) so technique_types/techniques
      # appear only once even if serializers or fragments overlap.
      included_raw = belts_included + technique_type_fragments + technique_fragments
      seen = {}
      deduped_included = []
      included_raw.each do |res|
        t = res[:type] || res['type']
        i = (res[:id] || res['id']).to_s
        key = "#{t}:#{i}"
        next if seen[key]
        deduped_included << res
        seen[key] = true
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
                belts: { data: belts_data },
                technique_types: { data: tt_ids.map { |id| { type: "technique_types", id: id.to_s } } }
              }
            },
            included: deduped_included
          }
    end

    etag = Digest::MD5.hexdigest(cache_key)
    last_modified = [@syllabus.updated_at, Time.at(last_belt_ts || 0), Time.at(last_tt_ts || 0), Time.at(last_tech_ts || 0)].compact.max
    return head(:not_modified) unless stale?(etag: etag, last_modified: last_modified)

    render json: payload
  end

  # DELETE /syllabi/:id
  # Destroys the syllabus and its dependent records (belts, user_syllabi, etc.).
  def destroy
    @syllabus.destroy
    head :no_content
  end

  # PUT/PATCH /syllabi/:id
  # Updates the syllabus.
  def update
    if @syllabus.update(syllabus_params)
      render json: @syllabus, status: :ok
    else
      render(
        json: {
          errors: @syllabus.errors.full_messages
        },
        status: :unprocessable_entity
      )
    end
  end

  # GET /syllabi/primary
  # Finds and renders the syllabus marked as the primary admin syllabus.
  def get_primary
    syllabus = Syllabus.find_by(is_primary_admin_syllabus: true)

    if syllabus
      last_belt_ts = syllabus.belts.maximum(:updated_at)&.to_i
      cache_key = ['syllabus_primary', syllabus.id, syllabus.updated_at.to_i, last_belt_ts].join('/')

      payload = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
          visible = syllabus.visible_belts_for(nil) rescue syllabus.belts
          visible_ids = if visible.respond_to?(:distinct)
            visible.distinct.reorder(nil).pluck(:id)
          else
            Array(visible).map(&:id).compact.uniq
          end

          belts = Belt.where(id: visible_ids).includes(technique_types: :techniques).order(:kyu_number)

          belts_serialized = BeltJsonapiSerializer.new(
            belts,
            include: [:technique_types, :'technique_types.techniques']
          ).serializable_hash

          belts_data = belts.map { |b| { type: "belts", id: b.id.to_s } }

          belts_included = []
          seen_belts = {}

          tt_ids = belts.flat_map { |b| Array(b.technique_types).map(&:id) }.uniq

          technique_type_fragments = tt_ids.map do |tt_id|
            tt = TechniqueType.find_by(id: tt_id)
            next unless tt
            tt_fragment_key = [
              'syllabus',
              syllabus.id,
              'technique_type',
              tt.id,
              tt.updated_at.to_i
            ].join('/')

            Rails.cache.read(tt_fragment_key)
          end.compact

          technique_records = Technique.where(technique_type_id: tt_ids).pluck(:id, :updated_at)
          technique_fragments = technique_records.map do |id, updated_at|
            key = ['syllabus', syllabus.id, 'technique', id, updated_at.to_i].join('/')
            Rails.cache.read(key)
          end.compact

          belts.each do |belt|
            next if seen_belts[belt.id]

            belt_fragment_key = [
              'syllabus',
              syllabus.id,
              'belt',
              belt.id,
              belt.updated_at.to_i
            ].join('/')

            belt_resource = Rails.cache.fetch(belt_fragment_key, expires_in: 6.hours) do
              tts = Array(belt.technique_types)
              tt_linkage = tts.map { |tt| { type: "technique_types", id: tt.id.to_s } }

              eff = if belt.kyu_number.respond_to?(:to_i)
                      ((belt.kyu_number - 1) % 8) + 1
                    end

              {
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
            included: (belts_included + technique_type_fragments + technique_fragments + (belts_serialized[:included] || []))
          }
      end

      etag = Digest::MD5.hexdigest(cache_key)
      last_modified = [syllabus.updated_at, Time.at(last_belt_ts || 0)].compact.max
      return head(:not_modified) unless stale?(etag: etag, last_modified: last_modified)

      render json: payload
    else
      # Returns 404 if no syllabus is currently marked as primary
      render json: { error: "Primary syllabus not found." }, status: :not_found
    end
  end

  # GET /syllabi/secondary
  # Finds and renders the syllabus marked as the secondary admin syllabus.
  def get_secondary
    syllabus = Syllabus.find_by(is_secondary_admin_syllabus: true)

    if syllabus
      last_belt_ts = syllabus.belts.maximum(:updated_at)&.to_i
      cache_key = ['syllabus_secondary', syllabus.id, syllabus.updated_at.to_i, last_belt_ts].join('/')

      payload = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
          visible = syllabus.visible_belts_for(nil) rescue syllabus.belts
          visible_ids = if visible.respond_to?(:distinct)
            visible.distinct.reorder(nil).pluck(:id)
          else
            Array(visible).map(&:id).compact.uniq
          end

          belts = Belt.where(id: visible_ids).includes(technique_types: :techniques).order(:kyu_number)

        belts_serialized = BeltJsonapiSerializer.new(
          belts,
          include: [:technique_types, :'technique_types.techniques']
        ).serializable_hash

        belts_data = belts.map { |b| { type: "belts", id: b.id.to_s } }

        belts_included = []
        seen_belts = {}

        tt_ids = belts.flat_map { |b| Array(b.technique_types).map(&:id) }.uniq

        technique_type_fragments = tt_ids.map do |tt_id|
          tt = TechniqueType.find_by(id: tt_id)
          next unless tt
          tt_fragment_key = [
            'syllabus',
            syllabus.id,
            'technique_type',
            tt.id,
            tt.updated_at.to_i
          ].join('/')

          Rails.cache.read(tt_fragment_key)
        end.compact

        technique_records = Technique.where(technique_type_id: tt_ids).pluck(:id, :updated_at)
        technique_fragments = technique_records.map do |id, updated_at|
          key = ['syllabus', syllabus.id, 'technique', id, updated_at.to_i].join('/')
          Rails.cache.read(key)
        end.compact

        belts.each do |belt|
          next if seen_belts[belt.id]

          belt_fragment_key = [
            'syllabus',
            syllabus.id,
            'belt',
            belt.id,
            belt.updated_at.to_i
          ].join('/')

          belt_resource = Rails.cache.fetch(belt_fragment_key, expires_in: 6.hours) do
            tts = Array(belt.technique_types)
            tt_linkage = tts.map { |tt| { type: "technique_types", id: tt.id.to_s } }

            eff = if belt.kyu_number.respond_to?(:to_i)
                    ((belt.kyu_number - 1) % 8) + 1
                  end

            {
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
          included: (belts_included + technique_type_fragments + technique_fragments + (belts_serialized[:included] || []))
        }
      end

      etag = Digest::MD5.hexdigest(cache_key)
      last_modified = [syllabus.updated_at, Time.at(last_belt_ts || 0)].compact.max
      return head(:not_modified) unless stale?(etag: etag, last_modified: last_modified)

      render json: payload
    else
      render json: {
               error: "Secondary syllabus not found."
             },
             status: :not_found
    end
  end

  # GET /syllabi/:syllabus_id/user_grade_syllabus
  # TODO: confirm that the route and the params are in alignment.
  # Returns the syllabus with belts filtered based on the current user's grade.
  def user_grade_syllabus
    # Use a simple find here and let the serializer/control code request
    # the minimal include: to populate JSON:API `included` resources. Avoid
    # duplicative `.includes(...)` here because `Syllabus#visible_belts_for`
    # and serializers may already preload associations and eager-loading in
    # multiple places increases object instantiation and render time.
    @syllabus = Syllabus.find(params[:id])

    # Ensure the user is authenticated, as the filtering is user-dependent.
    unless current_api_v1_user.present?
      # Respond with an explicit unauthorized status
      render json: {
               error: "Authentication required for graded syllabus view."
             },
             status: :unauthorized and return
    end

        # Determine serialization strategy. We allow explicit overrides via
        # params (?use_ams or ?use_jsonapi). Otherwise consult the global
        # configured default. This enables toggling strategy in one place
        # (config initializer) and preserves the ability to override per-request.
        prefer = Rails.application.config.respond_to?(:syllabus_serialization_default) ? Rails.application.config.syllabus_serialization_default.to_s : 'presenter'

        if params[:use_ams].present? && (params[:use_ams] == "true" || params[:use_ams] == "1")
          prefer = 'ams'
        elsif params[:use_jsonapi].present? && (params[:use_jsonapi] == "true" || params[:use_jsonapi] == "1")
          prefer = 'jsonapi'
        end

        case prefer
        when 'ams'
          render json: @syllabus,
                 serializer: SyllabusLimitedSerializer,
                 include: [
                   "belts",
                   "belts.technique_types",
                   "belts.technique_types.techniques"
                 ] and return
        when 'jsonapi'
          # Build a cache key that changes when the syllabus or related resources
          # are updated or when the requesting user's effective kyu changes.
          user = current_api_v1_user
          current_belt_grade = user&.belt_grades&.joins(:belt)&.where(belts: { syllabus_id: @syllabus.id })&.order(obtained_at: :desc)&.first
          user_kyu = current_belt_grade&.belt&.kyu_number || 8

          belts = @syllabus.visible_belts_for(user)

          last_belt_ts = belts.maximum(:updated_at)&.to_i
          last_tt_ts = TechniqueType.where(syllabus_id: @syllabus.id).maximum(:updated_at)&.to_i
          last_tech_ts = Technique.joins(:technique_type).where(technique_types: { syllabus_id: @syllabus.id }).maximum(:updated_at)&.to_i

          cache_key = [
            'syllabus',
            @syllabus.id,
            'user_grade',
            user_kyu,
            @syllabus.updated_at.to_i,
            last_belt_ts,
            last_tt_ts,
            last_tech_ts
          ].join('/')

          # If the request asks to warm the cache (admin override), enqueue the job
          if params[:warm_cache].present? && (params[:warm_cache] == '1' || params[:warm_cache] == 'true')
            # Use inline in development so it runs immediately when server is up
            if Rails.env.development?
              WarmSyllabusCacheJob.perform_now(@syllabus.id, user&.id)
            else
              WarmSyllabusCacheJob.perform_later(@syllabus.id, user&.id)
            end
          end

          payload = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
            belts_data = belts.map { |b| { type: "belts", id: b.id.to_s } }

            # Preload TechniqueType records for all visible belts to avoid per-belt queries
            belt_ids = belts.map(&:id)
            tts = TechniqueType.where(belt_id: belt_ids).includes(:techniques)
            tt_map = tts.group_by(&:belt_id)

            belts_included = []
            seen_belts = {}

            belts.each do |belt|
              next if seen_belts[belt.id]

              # Fragment-cache each belt's resource object so updates to other
              # belts or unrelated resources don't force rebuilding these hashes.
              belt_fragment_key = [
                'syllabus',
                @syllabus.id,
                'belt',
                belt.id,
                belt.updated_at.to_i
              ].join('/')

              belt_resource = Rails.cache.fetch(belt_fragment_key, expires_in: 6.hours) do
                tts_for_belt = tt_map[belt.id] || []
                tt_linkage = tts_for_belt.map { |tt| { type: "technique_types", id: tt.id.to_s } }

                eff = if belt.kyu_number.respond_to?(:to_i)
                        ((belt.kyu_number - 1) % 8) + 1
                      end

                {
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
              end

              belts_included << belt_resource
              seen_belts[belt.id] = true
            end

            # Collect technique_type ids from preloaded tts to fetch fragment entries
            tt_ids = tts.map(&:id)

            # Load technique_types and techniques in bulk and build maps by belt and technique_type
            tts = TechniqueType.where(id: tt_ids).includes(:techniques)

            technique_type_fragments = tt_ids.map do |tt_id|
              tt = tts.find { |t| t.id == tt_id }
              next unless tt
              tt_fragment_key = [
                'syllabus',
                @syllabus.id,
                'technique_type',
                tt.id,
                tt.updated_at.to_i
              ].join('/')

              Rails.cache.read(tt_fragment_key)
            end.compact

            # Fetch per-technique fragments for included techniques using preloaded technique records
            technique_records = tts.flat_map { |tt| tt.techniques }.map { |t| [t.id, t.updated_at] }
            technique_fragments = technique_records.map do |id, updated_at|
              key = ['syllabus', @syllabus.id, 'technique', id, updated_at.to_i].join('/')
              Rails.cache.read(key)
            end.compact

            # Deduplicate included resources (type + id) so technique_types/techniques
            # appear only once even if serializers or fragments overlap.
            included_raw = belts_included + technique_type_fragments + technique_fragments
            seen = {}
            deduped_included = []
            included_raw.each do |res|
              t = res[:type] || res['type']
              i = (res[:id] || res['id']).to_s
              key = "#{t}:#{i}"
              next if seen[key]
              deduped_included << res
              seen[key] = true
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
              included: deduped_included
            }
          end

          # HTTP caching: compute ETag/Last-Modified from the cache key and resource timestamps
          etag = Digest::MD5.hexdigest(cache_key)
          last_modified = [@syllabus.updated_at, Time.at(last_belt_ts || 0), Time.at(last_tt_ts || 0), Time.at(last_tech_ts || 0)].compact.max

          return head(:not_modified) unless stale?(etag: etag, last_modified: last_modified)

          render json: payload and return
        else
          # Default: presenter (fast, deterministic manual JSON:API payload)
          presenter = ::SyllabusPresenter.new(@syllabus, current_api_v1_user)
          render json: presenter.as_jsonapi and return
        end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Syllabus not found." }, status: :not_found
  end

  def set_primary
    # 1. Start a transaction to ensure both steps succeed or fail together
    Syllabus.transaction do
      # 2. Clear the 'is_primary_admin_syllabus' flag for ALL syllabi
      Syllabus.update_all(is_primary_admin_syllabus: false)

      # 3. Find the selected syllabus and set its flag to true
      syllabus = Syllabus.find_by(id: params[:syllabus_id])

      if syllabus
        syllabus.update!(is_primary_admin_syllabus: true) # Use update! to raise an error if it fails
        Rails.logger.info("Primary syllabus updated to ID: #{syllabus.id}")
        render json: {
                 status: "success",
                 message: "Primary syllabus updated."
               },
               status: :ok
      else
        # If the ID provided was invalid
        render json: {
                 status: "error",
                 message: "Syllabus not found."
               },
               status: :not_found
      end
    rescue => e
      # If anything in the transaction failed, log and return an error
      Rails.logger.error("Primary syllabus update failed: #{e.message}")
      render json: {
               status: "error",
               message:
                 "Failed to update primary syllabus due to a database error."
             },
             status: :unprocessable_entity
    end
  end

  def set_secondary
    Syllabus.transaction do
      # 2. Clear the 'is_secondary_admin_syllabus' flag for ALL syllabi
      Syllabus.update_all(is_secondary_admin_syllabus: false)

      # 3. Find the selected syllabus and set its flag to true
      syllabus = Syllabus.find_by(id: params[:syllabus_id])

      if syllabus
        syllabus.update!(is_secondary_admin_syllabus: true) # Use update! to raise an error if it fails
        Rails.logger.info("Secondary syllabus updated to ID: #{syllabus.id}")
        render json: {
                 status: "success",
                 message: "Secondary syllabus updated."
               },
               status: :ok
      else
        # If the ID provided was invalid
        render json: {
                 status: "error",
                 message: "Syllabus not found."
               },
               status: :not_found
      end
    rescue => e
      # If anything in the transaction failed, log and return an error
      Rails.logger.error("Secondary syllabus update failed: #{e.message}")
      render json: {
               status: "error",
               message:
                 "Failed to update secondary syllabus due to a database error."
             },
             status: :unprocessable_entity
    end
  end

  # POST /syllabi/:id/warm_cache
  # Admin-only endpoint to warm the cache for a specific syllabus immediately.
  def warm_cache
    authorize_admin!
    syllabus = Syllabus.find_by(id: params[:id])
    return render(json: { error: 'Syllabus not found' }, status: :not_found) unless syllabus

    if Rails.env.development?
      WarmSyllabusCacheJob.perform_now(syllabus.id, current_api_v1_user&.id)
    else
      WarmSyllabusCacheJob.perform_later(syllabus.id, current_api_v1_user&.id)
    end

    head :accepted
  end

  private

  # Strong parameters for Syllabus model.
  def syllabus_params
    # TODO: is syllbus_id needed here? It shouldn't be if it's a primary key, is it?
    params.require(:syllabus).permit(:country, :year, :syllabus_id)
  end

  # Reusable method to find a syllabus by its ID.
  def find_syllabus
    # Use find to automatically raise ActiveRecord::RecordNotFound,
    # which is handled by our rescue_from block.
    @syllabus = Syllabus.find(params[:id])
  end

  # Error handling methods.
  def record_not_found
    render(
      json: {
        status: 404,
        errors: {
          msg: "Record Not Found"
        }
      },
      status: :not_found
    )
  end

  def record_invalid(error)
    render json: {
             status: 422,
             errors: error.record.errors.full_messages
           },
           status: :unprocessable_entity
  end
end
