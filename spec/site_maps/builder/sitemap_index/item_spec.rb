# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::SitemapIndex::Item do
  describe "#to_xml" do
    it "returns the XML representation" do
      item = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 1, 1))
      xml = item.to_xml

      expect(xml.strip).to eq(<<~XML.split("\n").map(&:strip).join)
        <sitemap>
          <loc>https://example.com/sitemap.xml</loc>
          <lastmod>2019-01-01</lastmod>
        </sitemap>
      XML
    end

    it "does not include the lastmod tag if not provided" do
      item = described_class.new("https://example.com/sitemap.xml")
      xml = item.to_xml

      expect(xml.strip).to eq(<<~XML.split("\n").map(&:strip).join)
        <sitemap>
          <loc>https://example.com/sitemap.xml</loc>
        </sitemap>
      XML
    end
  end

  describe "#eql?" do
    it "returns true if the loc is the same" do
      item1 = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 1, 1))
      item2 = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 2, 2))

      expect(item1).to eql(item2)
    end

    it "returns false if the loc is different" do
      item1 = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 1, 1))
      item2 = described_class.new("https://example.com/sitemap_index.xml", Date.new(2019, 1, 1))

      expect(item1).not_to eql(item2)
    end
  end

  describe "#relative_directory" do
    it "returns the filename when it is in the root" do
      item = described_class.new("https://example.com/sitemap2.xml")
      expect(item.relative_directory).to eq("")
    end

    it "returns the relative path when it is not in the root" do
      item = described_class.new("https://example.com/sitemap/sitemap2.xml")
      expect(item.relative_directory).to eq("sitemap")
    end
  end

  describe "#hash" do
    it "returns the hash of the loc" do
      item = described_class.new("https://example.com/sitemap.xml")
      expect(item.hash).to eq("https://example.com/sitemap.xml".hash)
    end

    it "is the same for two items with the same loc" do
      item1 = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 1, 1))
      item2 = described_class.new("https://example.com/sitemap.xml", Date.new(2019, 2, 2))

      expect(item1.hash).to eq(item2.hash)
    end
  end
end
