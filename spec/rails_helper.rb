require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort "The Rails environment is running in production mode!" if Rails.env.production?

require "rspec/rails"
require_relative "support/openapi_contract"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => error
  abort error.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
end
