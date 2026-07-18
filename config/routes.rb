scope 'projects/:project_id' do
  resources :custom_dashboards, only: [:index]
end
