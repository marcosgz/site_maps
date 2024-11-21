# frozen_string_literal: true

require "singleton"
Kernel.require "rails/railtie"

module SiteMaps
  class Railtie < ::Rails::Railtie
    initializer "site_maps.named_routes" do
      named_route = Class.new do
        include Singleton
        include ::Rails.application.routes.url_helpers
      end
      SiteMaps::Adapters::Adapter.prepend(Module.new do
        define_method(:route) { named_route.instance }
      end)
    end
  end
end
