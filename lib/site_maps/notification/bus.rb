# frozen_string_literal: true

module SiteMaps
  module Notification
    class Bus
      attr_reader :listeners, :events

      def initialize
        @listeners = Concurrent::Hash.new { |h, k| h[k] = Concurrent::Array.new }
        @events = Concurrent::Hash.new
      end

      def publish(event_id, payload)
        raise UnregisteredEventError, event_id unless can_handle?(event_id)

        process(event_id, payload) do |event, listener|
          # Concurrent::Future.execute { listener.call(event) }
          listener.call(event)
        end
        self
      end

      def attach(listener)
        events.each do |id, event|
          method_name = event.listener_method
          next unless listener.respond_to?(method_name)

          listeners[id] << listener.method(method_name)
        end
        self
      end

      def unsubscribe(listener)
        listeners.each do |id, arr|
          arr.each do |func|
            listeners[id].delete(func) if func.receiver == listener
          end
        end
        self
      end
      alias_method :detach, :unsubscribe

      def subscribe(object_or_event_id, &block)
        raise(InvalidSubscriberError, object_or_event_id) unless can_handle?(object_or_event_id)

        if block
          listeners[object_or_event_id] << block
        else
          attach(object_or_event_id)
        end

        self
      end

      # rubocop:disable Performance/RedundantEqualityComparisonBlock
      def subscribed?(listener)
        listeners.values.any? { |value| value.any? { |func| func == listener } } ||
          (
            methods = events.values.map(&:listener_method)
              .select { |method_name| listener.respond_to?(method_name) }
              .map { |method_name| listener.method(method_name) }
            methods && listeners.values.any? { |value| (methods & value).size > 0 }
          )
      end
      # rubocop:enable Performance/RedundantEqualityComparisonBlock

      def can_handle?(object_or_event_id)
        case object_or_event_id
        when String, Symbol
          events.key?(object_or_event_id)
        else
          events
            .values
            .map(&:listener_method)
            .any? { |method_name| object_or_event_id.respond_to?(method_name) }
        end
      end

      protected

      def process(event_id, payload)
        listeners[event_id].each do |listener|
          event = events[event_id].payload(payload)

          yield(event, listener)
        end
      end
    end
  end
end
