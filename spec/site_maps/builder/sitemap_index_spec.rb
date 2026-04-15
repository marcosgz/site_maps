# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::SitemapIndex do
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
      sitemap_index.add("https://example.com/sitemap.xml", lastmod: Time.now - 1)
      sitemap_index.add("https://example.com/sitemap.xml", lastmod: Time.now + 1)

      expect(sitemap_index.sitemaps.size).to eq(1)
    end

    it "allows adding a sitemap item" do
      sitemap_index = described_class.new
      sitemap_index.add(item = SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/sitemap.xml"))

      expect(sitemap_index.sitemaps.size).to eq(1)
      expect(sitemap_index.sitemaps.first).to be(item)
    end
  end

  describe "xsl_url support" do
    it "includes the XSL processing instruction when xsl_url is set" do
      sitemap_index = described_class.new(xsl_url: "https://example.com/index-style.xsl")
      sitemap_index.add("https://example.com/sitemap.xml")

      xml = sitemap_index.to_xml

      expect(xml).to include('<?xml-stylesheet type="text/xsl" href="https://example.com/index-style.xsl"?>')
      expect(xml).to include("<sitemapindex")
    end

    it "does not include XSL processing instruction by default" do
      sitemap_index = described_class.new
      sitemap_index.add("https://example.com/sitemap.xml")

      xml = sitemap_index.to_xml

      expect(xml).not_to include("xml-stylesheet")
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
