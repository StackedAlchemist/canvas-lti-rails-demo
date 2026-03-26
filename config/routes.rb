Rails.application.routes.draw do
  # LTI 1.3 OIDC flow
  post "/lti/login",  to: "lti#login",  as: :lti_login
  post "/lti/launch", to: "lti#launch", as: :lti_launch
  get  "/.well-known/jwks.json", to: "lti#jwks", as: :jwks

  # Dashboard (root after LTI launch)
  get "/dashboard", to: "dashboard#show", as: :dashboard

  # Versioned content authoring
  resources :course_contents do
    resources :content_versions, only: %i[new create] do
      member do
        post :publish
        post :rollback
      end
    end
  end

  # Grade passback
  post "/grades/submit", to: "grades#submit", as: :grades_submit

  # AI Study Assistant
  post "/ai/chat",       to: "ai_assistant#chat",      as: :ai_chat
  get  "/ai/analytics",  to: "ai_assistant#analytics",  as: :ai_analytics

  # Sidekiq web UI — requires active LTI session
  mount Sidekiq::Web => "/sidekiq", constraints: ->(req) {
    launch_id = req.session[:lti_launch_id]
    launch_id.present? && LtiLaunch.find_by(id: launch_id)&.instructor?
  }

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest"       => "rails/pwa#manifest",       as: :pwa_manifest
end
