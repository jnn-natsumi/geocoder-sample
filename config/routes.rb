Rails.application.routes.draw do
  root "spots#index"
  resources :spots
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
