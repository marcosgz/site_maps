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
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.host = "https://example.com"
        config.directory = "tmp"
      end

      expect(described_class.config.host).to eq("https://example.com")
      expect(described_class.config.directory).to eq("tmp")
    end
  end
end
