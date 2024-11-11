# frozen_string_literal: true

class SiteMaps::Adapters::FileSystem::Config < SiteMaps::Configuration
  attribute :directory, default: "public/sitemaps"
end
