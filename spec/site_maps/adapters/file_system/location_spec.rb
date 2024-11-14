# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::FileSystem::Location do
  describe "#path" do
    it "returns the full path to the file" do
      location = described_class.new("/app/root/public", "http://example.com/sitemaps/2024/sitemap1.xml")
      expect(location.path).to eq("/app/root/public/sitemaps/2024/sitemap1.xml")
    end

    it "returns the full path when the root has a trailing slash" do
      location = described_class.new("/app/root/public/", "http://example.com/sitemaps/2024/sitemap1.xml")
      expect(location.path).to eq("/app/root/public/sitemaps/2024/sitemap1.xml")
    end
  end

  describe "#directory" do
    it "returns the directory path" do
      location = described_class.new("/app/root/public", "http://example.com/sitemaps/2024/sitemap1.xml")
      expect(location.directory).to eq("/app/root/public/sitemaps/2024")
    end

    it "returns the directory path when the root has a trailing slash" do
      location = described_class.new("/app/root/public/", "http://example.com/sitemaps/2024/sitemap1.xml")
      expect(location.directory).to eq("/app/root/public/sitemaps/2024")
    end
  end

  describe "#gzip?" do
    it "returns true when the path ends with .gz" do
      location = described_class.new("/app/root/public", "http://example.com/sitemaps/2024/sitemap1.xml.gz")
      expect(location.gzip?).to eq(true)
    end

    it "returns false when the path does not end with .gz" do
      location = described_class.new("/app/root/public", "http://example.com/sitemaps/2024/sitemap1.xml")
      expect(location.gzip?).to eq(false)
    end
  end
end
