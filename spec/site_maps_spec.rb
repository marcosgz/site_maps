# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps do
  it "has a version number" do
    expect(SiteMaps::VERSION).not_to be_nil
  end

  describe ".use" do
    it "returns an instance of the adapter" do
      adapter = described_class.use(:file_system, directory: "tmp")
      expect(adapter).to be_a(SiteMaps::Adapters::FileSystem)
      expect(adapter.config.directory).to eq("tmp")
    end

    it "raises an error if the adapter is not found" do
      expect {
        described_class.use(:unknown)
      }.to raise_error(SiteMaps::AdapterNotFound)
    end

    it "uses the given adapter class" do
      adapter = Class.new(SiteMaps::Adapters::Adapter)
      config = Class.new(SiteMaps::Configuration)
      adapter.const_set(:Config, config)

      expect(described_class.use(adapter)).to be_an_instance_of(adapter)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.url = "https://example.com/sitemap.xml"
        config.directory = "tmp"
      end

      expect(described_class.config.url).to eq("https://example.com/sitemap.xml")
      expect(described_class.config.directory).to eq("tmp")
    end
  end
end
