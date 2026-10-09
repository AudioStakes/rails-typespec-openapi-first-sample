source "https://rubygems.org"

ruby "4.0.6"

gem "rails", "8.1.3.1"
gem "sqlite3", "~> 2.9"
gem "puma", "~> 7.0"
gem "openapi_first", "4.2.0"
# Rails 8.1's JSON decoder passes positional options; JSON 3 requires keywords.
gem "json", "2.21.2"

gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "rspec-rails", "8.0.4"
end
