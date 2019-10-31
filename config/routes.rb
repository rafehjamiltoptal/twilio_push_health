Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'twilio#new'

  resources :twilio, only: %i[new create] do
    collection do
      get 'connect'
      post 'connect'
    end
  end

  resources :twilio_sms, only: %i[new create] do
    collection do
      post 'verify_code'
    end
  end
end
