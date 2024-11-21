# frozen_string_literal: true

require "singleton"
Kernel.require "rails/railtie"

module SiteMaps
  class Railtie < ::Rails::Railtie
    module URLExtension
      class NamedRoute
        include Singleton
        include ::Rails.application.routes.url_helpers
      end

      def route
        NamedRoute.instance
      end
    end

    initializer "site_maps.named_routes" do
      SiteMaps::Adapters::Adapter.prepend(URLExtension)
    end
  end
end
