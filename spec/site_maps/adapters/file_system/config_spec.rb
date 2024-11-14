# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::FileSystem::Config do
  describe "#initialize" do
    it "sets the default values" do
      config = described_class.new

      expect(config.directory).to eq("public/sitemaps")
    end

    it "sets the provided values" do
      config = described_class.new(
        url: "https://example.com/sitemap.xml",
        directory: "tmp"
      )

      expect(config.url).to eq("https://example.com/sitemap.xml")
      expect(config.directory).to eq("tmp")
    end
  end
end
