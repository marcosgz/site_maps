# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "dotenv/load"
require "pry"
require "nokogiri"
require "webmock/rspec"
require "site_maps"

# require_relative "dummy/config/environment"
# ActiveRecord::Migrator.migrations_paths = [File.expand_path("../dummy/db/migrate", __FILE__)]
# require "rails/test_help"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
