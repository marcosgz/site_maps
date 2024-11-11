# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::FileSystem::Config do
  describe "#initialize" do
    it "sets the default values" do
      config = described_class.new

      expect(config.host).to be_nil
      expect(config.directory).to eq("public/sitemaps")
      expect(config.main_filename).to eq("sitemap.xml")
    end

    it "sets the provided values" do
      config = described_class.new(
        host: "https://example.com",
        directory: "tmp",
        main_filename: "sitemap_index.xml.gz"
      )

      expect(config.host).to eq("https://example.com")
      expect(config.directory).to eq("tmp")
      expect(config.main_filename).to eq("sitemap_index.xml.gz")
    end
  end
end
