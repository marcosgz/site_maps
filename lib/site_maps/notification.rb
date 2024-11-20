# frozen_string_literal: true

module SiteMaps
  module Notification
    Error = Class.new(SiteMaps::Error)

    class UnregisteredEventError < Error
      def initialize(object_or_event_id)
        case object_or_event_id
        when String, Symbol
          super("You are trying to publish an unregistered event: `#{object_or_event_id}`")
        else
          super("You are trying to publish an unregistered event")
        end
      end
    end

    class InvalidSubscriberError < Error
      def initialize(object_or_event_id)
        case object_or_event_id
        when String, Symbol
          super("you are trying to subscribe to an event: `#{object_or_event_id}` that has not been registered")
        else
          super("you try use subscriber object that will never be executed")
        end
      end
    end

    include Publisher

    register_event "sitemaps.runner.execute"
    register_event "sitemaps.runner.process"
    register_event "sitemaps.builder.finalize_urlset"
  end
end
