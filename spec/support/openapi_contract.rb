# frozen_string_literal: true

module OpenapiContract
  def self.api_path?(path)
    path == "/api" || path.start_with?("/api/")
  end

  def self.expected_invalid_request?(request)
    expected = RSpec.current_example&.metadata&.fetch(:invalid_request, nil)
    expected && expected.fetch(:method) == request.request_method &&
      expected.fetch(:path) == request.path && expected.fetch(:error) == request.error&.type
  end

  # openapi_first 4.2 skips response validation when request media type routing
  # fails. Select the same operation's JSON representation to validate its 415.
  def self.validate_unsupported_media_type_response(request, response)
    json_request = Rack::Request.new(request.env.merge("CONTENT_TYPE" => "application/json"))
    validated = OpenapiFirst::Test[:default].validate_response(
      json_request, Rack::Response[response.status, response.headers, [ response.body ]], raise_error: true
    )
    raise OpenapiFirst::Error, "The 415 response was not checked against the API contract" unless validated
  end
end

OpenapiFirst::Test.setup do |test|
  # The defaults exempt invalid 401/404/500 responses, even for known statuses.
  test.ignored_unknown_status = []
  test.ignore_request_error do |request|
    (!OpenapiContract.api_path?(request.path) && request.unknown?) ||
      OpenapiContract.expected_invalid_request?(request)
  end
end

OpenapiFirst.configure do |config|
  # Test.setup tracks known invalid requests without raising. Require ordinary
  # examples to send valid requests, with precise exceptions for negative tests.
  config.after_request_validation do |request, _definition|
    next unless OpenapiContract.api_path?(request.path) && request.invalid?

    if OpenapiContract.expected_invalid_request?(request)
      RSpec.current_example.metadata[:openapi_expected_invalid_seen] = true
    else
      raise request.error.exception(request)
    end
  end
end

OpenapiFirst::Test.observe(Rails.application)

RSpec.configure do |config|
  config.after(:each, type: :request) do |example|
    next unless example.metadata[:invalid_request]

    expect(example.metadata.delete(:openapi_expected_invalid_seen)).to eq(true),
      "The example did not send the declared invalid request"
  end
end
