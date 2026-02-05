namespace :cache do
  namespace :warm do
    desc 'Warm syllabus caches (all syllabi)'
    task syllabi: :environment do
      require 'active_support/all'

      Syllabus.find_each do |s|
        # Enqueue jobs; in development these will run inline if configured
        if Rails.env.development?
          WarmSyllabusCacheJob.perform_now(s.id)
        else
          WarmSyllabusCacheJob.perform_later(s.id)
        end
      end
    end
  end
end
