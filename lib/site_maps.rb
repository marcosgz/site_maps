# frozen_string_literal: true

require_relative "site_maps/version"
require_relative "site_maps/railtie"

require "active_support"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/site_maps/tasks.rb")
loader.inflector.inflect "xml" => "XML"
loader.log! if ENV["DEBUG_ZEITWERK"]
loader.setup

module SiteMaps
end
