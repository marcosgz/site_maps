# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::XSLStylesheet do
  describe ".processing_instruction" do
    it "returns a valid processing instruction" do
      pi = described_class.processing_instruction("https://example.com/style.xsl")

      expect(pi).to eq('<?xml-stylesheet type="text/xsl" href="https://example.com/style.xsl"?>')
    end
  end

  describe ".urlset_xsl" do
    it "returns valid XML" do
      doc = Nokogiri::XML(described_class.urlset_xsl)

      expect(doc.errors).to be_empty
    end

    it "contains urlset table headers" do
      xsl = described_class.urlset_xsl

      expect(xsl).to include("URL")
      expect(xsl).to include("Images")
      expect(xsl).to include("Last Modified")
    end

    it "references the sitemap namespace" do
      xsl = described_class.urlset_xsl

      expect(xsl).to include("sitemap:urlset/sitemap:url")
    end
  end

  describe ".index_xsl" do
    it "returns valid XML" do
      doc = Nokogiri::XML(described_class.index_xsl)

      expect(doc.errors).to be_empty
    end

    it "contains index table headers" do
      xsl = described_class.index_xsl

      expect(xsl).to include("Sitemap")
      expect(xsl).to include("Last Modified")
    end

    it "references the sitemapindex namespace" do
      xsl = described_class.index_xsl

      expect(xsl).to include("sitemap:sitemapindex/sitemap:sitemap")
    end
  end
end
