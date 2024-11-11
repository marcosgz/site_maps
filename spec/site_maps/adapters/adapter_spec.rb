# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::Adapter do
  let(:adapter_config) do
    Class.new(SiteMaps::Configuration)
  end

  before do
    stub_const("SiteMaps::Adapters::Adapter::Config", adapter_config)
  end

  describe "#initialize" do
    subject(:adapter) do
      described_class.new
    end

    it "has a url_set" do
      expect(adapter.url_set).to be_a(SiteMaps::Sitemap::URLSet)
    end

    context "when initialized with options" do
      subject(:adapter) do
        described_class.new(host: "https://example.com")
      end

      it "has options" do
        expect(adapter.config.host).to eq("https://example.com")
      end
    end

    context "when initialized with a block" do
      it "yields itself" do
        allow_any_instance_of(SiteMaps::Sitemap::URLSet).to receive(:add) # rubocop:disable RSpec/AnyInstance
        adapter = described_class.new do |sitemap|
          sitemap.config.host = "https://example.com"
        end

        expect(adapter.config.host).to eq("https://example.com")
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

  describe "#build_link" do
    subject(:adapter) do
      described_class.new
    end

    context "when host is not set" do
      it "raises an error" do
        expect { adapter.send(:build_link, "/path", nil) }.to raise_error(SiteMaps::ConfigurationError)
      end
    end

    context "when host is set" do
      it "returns a link" do
        adapter.config.host = "https://example.com"
        link = adapter.send(:build_link, "/path", nil)
        expect(link).to be_a(SiteMaps::Sitemap::Link)
      end
    end
  end
end
