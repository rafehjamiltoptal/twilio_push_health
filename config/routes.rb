Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "twilio#new"

  resources :twilio do
    collection do
      get 'connect'
      post 'connect'
    end
  end
end
