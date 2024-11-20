# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Notification::Publisher do
  subject(:publisher) do
    Class.new do
      include SiteMaps::Notification::Publisher

      register_event :test_event
    end
  end

  describe ".register_event" do
    it "registers a new event" do
      listener = ->(*) {}

      publisher.register_event(:test_another_event).subscribe(:test_another_event, &listener)

      expect(publisher.subscribed?(listener)).to be(true)
    end
  end

  describe ".subscribe" do
    it "raises an exception when subscribing to an unregister event" do
      listener = ->(*) {}

      expect {
        publisher.subscribe(:not_register, &listener)
      }.to raise_error(SiteMaps::Notification::InvalidSubscriberError, /not_register/)
    end

    it "subscribes a listener function" do
      listener = ->(*) {}

      publisher.subscribe(:test_event, &listener)

      expect(publisher.subscribed?(listener)).to be(true)
    end

    it "subscribes and unsubscribe a listener object" do
      listener = Class.new do
        attr_reader :captured

        def initialize
          @captured = []
        end

        def on_test_event(event)
          captured << event[:message]
        end
      end.new

      publisher.subscribe(listener).publish(:test_event, message: "it works")
      expect(publisher.subscribed?(listener)).to be(true)
      expect(listener.captured).to eql(["it works"])

      publisher.unsubscribe(listener)

      expect(publisher.subscribed?(listener)).to be(false)
      publisher.publish(:test_event, message: "it works")

      expect(listener.captured).to eql(["it works"])
    end

    it "raises an exception when subscribing with no methods to execute" do
      listener = Object.new

      expect {
        publisher.subscribe(listener)
      }.to raise_error(SiteMaps::Notification::InvalidSubscriberError, /never be executed/)
    end

    it "does not raise an exception when subscriber has methods for notification" do
      listener = Object.new
      def listener.on_test_event
        nil
      end
      expect { publisher.subscribe(listener) }.not_to raise_error
    end
  end

  describe ".publish" do
    it "publishes an event" do
      result = []
      latch = Concurrent::CountDownLatch.new(1)
      listener = ->(event) do
        result << event[:message]
        latch.count_down
      end

      publisher.subscribe(:test_event, &listener).publish(:test_event, message: "it works")
      latch.wait

      expect(result).to eql(["it works"])
    end

    it "raises an exception when publishing an unregistered event" do
      expect {
        publisher.publish(:unregistered_event, {})
      }.to raise_error(SiteMaps::Notification::UnregisteredEventError, /unregistered_event/)
    end
  end

  describe ".instrument" do
    it "publishes an event" do
      result = []
      latch = Concurrent::CountDownLatch.new(1)
      listener = ->(event) do
        result << event.payload.slice(:external_msg, :internal_msg, :runtime, :__started_at__)
        latch.count_down
      end

      publisher.subscribe(:test_event, &listener).instrument(:test_event, external_msg: "e") do |payload|
        payload[:internal_msg] = "i"
        sleep 0.1
      end
      latch.wait

      expect(result.size).to eq(1)
      expect(result.dig(0, :external_msg)).to eq("e")
      expect(result.dig(0, :internal_msg)).to eq("i")
      expect(result.dig(0, :runtime)).to be_within(0.1).of(0.1)
      expect(result.dig(0, :__started_at__)).to be_nil
    end

    it "does not publishes an event if block throws an exception" do
      result = []
      listener = ->(event) { result << event }

      expect {
        publisher.subscribe(:test_event, &listener).instrument(:test_event) do |payload|
          payload[:msg] = "ignore"
          raise RuntimeError
        end
      }.to raise_error(RuntimeError)

      expect(result.size).to eq(0)
    end

    it "raises an exception when publishing an unregistered event" do
      expect {
        publisher.instrument(:unregistered_event, {}) { |*| }
      }.to raise_error(SiteMaps::Notification::UnregisteredEventError, /unregistered_event/)
    end
  end
end
