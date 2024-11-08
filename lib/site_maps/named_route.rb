# frozen_string_literal: true

require "singleton"

module SiteMaps
  class NamedRoute
    include Singleton
    include Rails.application.routes.url_helpers

    class << self
      def method_missing(method, *args, &block)
        instance.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method, include_private) || super
      end
    end
  end
end
