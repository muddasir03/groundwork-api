Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :companies, only: [ :index, :show ], param: :slug, constraints: { slug: Company::SLUG_PATTERN }

      namespace :admin do
        resource :session, only: [ :create, :show, :destroy ] do
          post :verify
        end
        resource :two_factor, only: [ :show ], controller: "two_factor" do
          post :setup
          post :confirm
          post :recovery_codes
        end
        resources :companies, only: [ :index, :show, :create, :update ], param: :slug, constraints: { slug: Company::SLUG_PATTERN } do
          member do
            put :report, action: :replace_report
            patch :status, action: :update_status
          end
        end
      end
    end
  end
end
