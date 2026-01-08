Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      root "users/omniauth_callbacks#passthru"

      # get '/test_route', to: 'api/v1/users#index'
      get "/csrf_token", to: "csrf_tokens#index"
      devise_for :users,
                 controllers: {
                   omniauth_callbacks: "api/v1/users/omniauth_callbacks",
                   sessions: "api/v1/sessions"
                 }, # Custom sessions controller is specified
                 skip: [:registrations],
                 failure_app:
                   "Api::V1::Users::OmniauthCallbacksController".constantize,
                 omniauth_providers: [:google_oauth2],
                 path: "",
                 path_names: {
                   failure: "auth/google_oauth2/failure"
                 }, # Explicitly set the failure path
                 omniauth_path: "/auth",
                 omniauth_callbacks: {
                   google_oauth2: "api/v1/users/omniauth_callbacks"
                 } do
        get "auth/failure",
            to: "api/v1/users/omniauth_callbacks#failure",
            as: :api_v1_omniauth_failure
      end

      # as: :api_v1_user
      # module: 'api/v1/users'

      # get '/users/auth/google_oauth2/failure', to: '/users/omniauth_callbacks#failure', as: :api_v1_omniauth_failure

      resources :users, except: %i[new edit] do
        collection do
          get :current
          get :email_available
        end
      end

      resource :session, only: %i[new create destroy]
      resources :profiles
      resources :whatisjiujitsu
      resources :admin
      resources :waivers do
        # Using `member` block for a route that acts on a single waiver
        collection { get :outstanding_count }
        member { get :find_waiver }
      end
      resources :technique_types do
        post :find, on: :collection
        get :search, on: :collection
      end

      resources :techniques do
        collection { get :find }

        # Uncomment upon returning video functionality
        # member do
        #   get :videos, to: "videos#group"
        # end
      end

      resources :videos do
        collection { get :by_technique }
      end

      resources :differences, only: %i[index show create update destroy] do
        # This custom 'collection' route creates a path for filtering
        # the collection of differences by a specific technique ID.
        # The resulting route will be /api/v1/differences/by_technique/:technique_id
        collection do
          get "by_technique/:technique_id", to: "differences#by_technique"
        end
      end

      resources :belt_grades, except: %i[new edit]
      resources :instructor_qualifications
      # --- Belt Routes ---
      # Add the standard RESTful routes for the Belt resource
      resources :belts

      # Add the custom route for finding belts
      get "/belts_find", { to: "belts#find" }

      # Add the nested Syllabus and Belt routes if necessary
      # This block defines routes like /api/v1/syllabi/:syllabus_id/belts
      resources :syllabi do
        collection do
          get :get_primary
          get :get_secondary
          put :set_primary
          # Alternatively, there's also: put 'set_primary', to: 'syllabi#set_primary'
          put :set_secondary
        end
        # Nested resources for belts under a specific syllabus
        resources :belts
        # Assuming we also have a mindmap resource nested under syllabi
        resources :mindmap
        # Assuming we also have a custom route under syllabi
        # get "/syllabi_full", {to: "syllabi#find_all_belts"}
        member do
          get "/user_grade_syllabus", { to: "syllabi#user_grade_syllabus" }
        end
      end
      # --- End Belt Routes ---

      # Test-only routes for base contract validation
      get "/trigger_500", to: "errors#boom", as: :trigger_500 if Rails.env.test?
    end
  end

  # get '/api/v1/users/auth/google_oauth2/failure', to: 'api/v1/users/omniauth_callbacks#failure', as: :api_v1_omniauth_failure
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
