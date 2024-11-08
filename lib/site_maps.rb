# frozen_string_literal: true

require_relative "site_maps/version"
# require_relative "site_maps/railtie"

# require "active_support"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/site-maps.rb")
loader.ignore("#{__dir__}/site_maps/tasks.rb")
loader.inflector.inflect "xml" => "XML"
loader.log! if ENV["DEBUG_ZEITWERK"]
loader.setup

module SiteMaps
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
