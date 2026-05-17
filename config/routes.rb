Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }
  root to: "pages#home"

  # Admin authentication routes (outside namespace for custom paths)
  get "admin/login", to: "admin/sessions#new", as: :admin_login
  post "admin/login", to: "admin/sessions#create"
  delete "admin/logout", to: "admin/sessions#destroy", as: :admin_logout

  # Admin routes
  namespace :admin do
    root to: "dashboard#index"
    resources :dashboard, only: [:index]
    resources :documents, only: [:index, :new, :create, :destroy] do
      collection do
        post :bulk_create
      end
    end
    resources :users do
      member do
        patch :toggle_status
        patch :update_role
      end
    end
    resources :categories
    resources :audit_logs, only: [:index, :show]
  end

  # Chat routes
  resources :conversations, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create] do
      member do
        post :feedback
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
