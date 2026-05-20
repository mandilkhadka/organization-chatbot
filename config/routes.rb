require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }
  root to: "pages#home"

  # Sidekiq Web — gated by Warden session. Accepts only authenticated users
  # whose role is admin AND whose admin session has not timed out.
  admin_constraint = lambda do |request|
    user = request.env["warden"]&.user
    user.present? && user.admin? && !user.admin_session_expired?
  end
  mount Sidekiq::Web => "/admin/sidekiq", constraints: admin_constraint

  # Admin authentication routes (outside namespace for custom paths)
  get "admin/login", to: "admin/sessions#new", as: :admin_login
  post "admin/login", to: "admin/sessions#create"
  delete "admin/logout", to: "admin/sessions#destroy", as: :admin_logout

  # Admin routes
  namespace :admin do
    root to: "dashboard#index"
    resources :dashboard, only: [:index]
    resources :documents, only: %i[index new create destroy] do
      collection do
        post :bulk_create
      end
    end
    resources :users do
      member do
        patch :update_role
      end
    end
    resources :categories
    resources :audit_logs, only: %i[index show]
  end

  # Chat routes
  resources :conversations, only: %i[index show create destroy] do
    resources :messages, only: [:create] do
      member do
        post :feedback
      end
    end
  end

  # Health endpoints
  # /up & /health  — liveness (200 iff Rails boots; safe for k8s liveness probes)
  # /health/deep   — readiness (200 only when Postgres + Redis are responsive)
  get "up" => "health#liveness", as: :rails_health_check
  get "health" => "health#liveness"
  get "health/deep" => "health#readiness"
end
