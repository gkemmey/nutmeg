Rails.application.routes.draw do
  root to: 'settings#show'

  resource :settings, only: [:show]

  namespace :settings do
    resource :billing,      only: [:new, :create, :destroy, :show]
    resource :subscription, only: [:new, :create, :destroy]
  end

  resources :stripe_events, only: [:create]
end
