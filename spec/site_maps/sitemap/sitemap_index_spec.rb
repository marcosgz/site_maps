# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Sitemap::SitemapIndex do
  describe "#to_xml" do
    it "returns the XML representation" do
      sitemap_index = described_class.new
      sitemap_index.add("https://example.com/sitemap.xml")

      xml = sitemap_index.to_xml

      expect(xml).to eq(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <sitemapindex
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd"
          xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        >
        <sitemap><loc>https://example.com/sitemap.xml</loc></sitemap>
        </sitemapindex>
      XML
    end
  end

  describe "#add" do
    it "adds a sitemap" do
      sitemap_index = described_class.new
      sitemap_index.add("https://example.com/sitemap.xml")

      expect(sitemap_index.sitemaps.size).to eq(1)
    end

    it "does not add the same sitemap twice" do
      sitemap_index = described_class.new
      sitemap_index.add("https://example.com/sitemap.xml")
      sitemap_index.add("https://example.com/sitemap.xml")

      expect(sitemap_index.sitemaps.size).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns true when there are no sitemaps" do
      sitemap_index = described_class.new

      expect(sitemap_index.empty?).to be(true)
    end

    it "returns false when there are sitemaps" do
      sitemap_index = described_class.new
      sitemap_index.add("https://example.com/sitemap.xml")

      expect(sitemap_index.empty?).to be(false)
    end
  end
end
