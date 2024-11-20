# frozen_string_literal: true

module SiteMaps::Notification
  module Publisher
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    # Class interface for publishers
    #
    # @api public
    module ClassMethods
      extend Forwardable
      def_delegators :bus, :publish, :subscribed?, :unsubscribe

      # Register a new event type
      #
      # @param [Symbol,String] event_id The event identifier
      # @param [Hash] payload Optional default payload
      #
      # @return [self]
      #
      # @api public
      def register_event(event_id, payload = {})
        bus.events[event_id] = Event.new(event_id, payload)
        self
      end

      # Publish an event with extra runtime information to the payload
      #
      # @param [String] event_id The event identifier
      # @param [Hash] payload An optional payload
      # @raise [UnregisteredEventError] if the event is not registered
      #
      # @api public
      def instrument(event_id, payload = {})
        publish_event = false # ensure block is also called on error
        raise(UnregisteredEventError, event_id) unless bus.can_handle?(event_id)

        payload[:__started_at__] = Time.now
        yield(payload).tap { publish_event = true }
      ensure
        if publish_event
          payload[:runtime] ||= Time.now - payload.delete(:__started_at__) if payload[:__started_at__]
          bus.publish(event_id, payload)
        end
      end

      # Subscribe to events.
      #
      # @param [Symbol,String,Object] object_or_event_id The event identifier or a listener object
      # @param [Hash] filter_hash An optional event filter
      #
      # @raise [SiteMaps::Notification::InvalidSubscriberError] if the subscriber is not registered
      # @return [Object] self
      #
      #
      # @api public
      def subscribe(object_or_event_id, &block)
        if bus.can_handle?(object_or_event_id)
          if block
            bus.subscribe(object_or_event_id, &block)
          else
            bus.attach(object_or_event_id)
          end

          self
        else
          raise InvalidSubscriberError, object_or_event_id
        end
      end

      def bus
        @bus ||= Bus.new
      end
    end
  end
end
