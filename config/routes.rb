Rails.application.routes.draw do
  namespace :api do
    resources :tasks, only: %i[index create show]
    patch "tasks/:id", to: "tasks#update"
  end
end
