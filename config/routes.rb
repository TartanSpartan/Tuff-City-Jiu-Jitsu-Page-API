Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      root 'users/omniauth_callbacks#passthru'

      # get '/test_route', to: 'api/v1/users#index'
      get '/csrf_token', to: 'csrf_tokens#index'
      devise_for :users,
      controllers: { omniauth_callbacks: 'api/v1/users/omniauth_callbacks',
      sessions: 'api/v1/sessions' }, # Custom sessions controller is specified
      skip: [:registrations],
      failure_app: 'Api::V1::Users::OmniauthCallbacksController'.constantize,
      omniauth_providers: [:google_oauth2],
      path: '',
      path_names: { failure: 'auth/google_oauth2/failure' }, # Explicitly set the failure path
      omniauth_path: '/auth',
      omniauth_callbacks: { 'google_oauth2': 'api/v1/users/omniauth_callbacks' } do
      get 'auth/failure', to: 'api/v1/users/omniauth_callbacks#failure', as: :api_v1_omniauth_failure
    end



        # as: :api_v1_user 
        # module: 'api/v1/users'

        # get '/users/auth/google_oauth2/failure', to: '/users/omniauth_callbacks#failure', as: :api_v1_omniauth_failure
    

      resources :users, only: [:index, :create, :update] do
        collection do
          get :current
          get :email_available
        end
      end
      resource :session, only: [:create, :destroy]
      resources :profiles
      resources :whatisjiujitsu
      resources :admin
    end
  end

  # get '/api/v1/users/auth/google_oauth2/failure', to: 'api/v1/users/omniauth_callbacks#failure', as: :api_v1_omniauth_failure
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end