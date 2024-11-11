# frozen_string_literal: true

require_relative "site_maps/version"
# require_relative "site_maps/railtie"

# require "active_support"
require "builder"
require "date"
require "fileutils"
require "rack/utils"
require "stringio"
require "time"
require "uri"
require "zeitwerk"
require "zlib"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/site-maps.rb")
loader.ignore("#{__dir__}/site_maps/tasks.rb")
loader.inflector.inflect "xml" => "XML"
loader.inflector.inflect "url" => "URL"
loader.inflector.inflect "url_set" => "URLSet"
loader.log! if ENV["DEBUG_ZEITWERK"]
loader.setup

module SiteMaps
  MAX_LENGTH = {
    links: 50_000,
    images: 1_000,
    news: 1_000
  }
  MAX_FILESIZE = 50_000_000 # bytes

  Error = Class.new(StandardError)
  FullSitemapError = Class.new(Error)
  ConfigurationError = Class.new(Error)

  # @param adapter_name [String, Symbol] The name of the adapter to use
  # @param options [Hash] Options to pass to the adapter. Note that these are adapter-specific
  # @param block [Proc] A block to pass to the adapter
  # @return [Object] An instance of the adapter
  def self.use(adapter_name, **options, &block)
    adapter_class = Primitives::String.new(adapter_name.to_s).classify
    adapter = Adapters.const_get(adapter_class)
    adapter.new(**options, &block)
  end
end
