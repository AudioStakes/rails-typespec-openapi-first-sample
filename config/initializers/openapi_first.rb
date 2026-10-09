# frozen_string_literal: true

OpenapiFirst.register(Rails.root.join("openapi/openapi.yaml"))

# openapi_first has no path filter. Keep the static frontend outside the API
# contract while using the native middleware for every /api request.
class ApiContractRequestValidation < OpenapiFirst::Middlewares::RequestValidation
  def call(env)
    path = env.fetch("PATH_INFO", "")
    return app.call(env) unless path == "/api" || path.start_with?("/api/")

    super
  end
end

Rails.application.config.middleware.use(ApiContractRequestValidation)
