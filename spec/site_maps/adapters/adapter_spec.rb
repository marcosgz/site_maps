# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::Adapter do
  describe "#initialize" do
    subject(:adapter) do
      described_class.new
    end

    it "has options" do
      expect(adapter.options).to eq({})
    end

    it "has a builder" do
      expect(adapter.builder).to be_a(SiteMaps::Builder)
    end

    context "when initialized with options" do
      subject(:adapter) do
        described_class.new(foo: :bar)
      end

      it "has options" do
        expect(adapter.options).to eq(foo: :bar)
      end
    end

    context "when initialized with a block" do
      it "yields the builder" do
        allow_any_instance_of(SiteMaps::Builder).to receive(:add)
        adapter = described_class.new do |sitemap|
          sitemap.add("/")
        end

        expect(adapter.builder).to have_received(:add).with("/")
      end
    end
  end

  describe "#config" do
    subject(:adapter) do
      described_class.new
    end

    it "has a configuration" do
      expect(adapter.config).to be_a(SiteMaps::Configuration)
    end
  end

  describe "#configure" do
    subject(:adapter) do
      described_class.new
    end

    it "yields self" do
      config = adapter.config
      expect { |b| adapter.configure(&b) }.to yield_with_args(config)
    end
  end
end
