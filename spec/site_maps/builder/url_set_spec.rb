# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::URLSet do
  describe "SCHEMAS" do
    it "contains the expected schemas" do
      expect(described_class::SCHEMAS).to eq(
        "image" => "http://www.google.com/schemas/sitemap-image/1.1",
        "mobile" => "http://www.google.com/schemas/sitemap-mobile/1.0",
        "news" => "http://www.google.com/schemas/sitemap-news/0.9",
        "pagemap" => "http://www.google.com/schemas/sitemap-pagemap/1.0",
        "video" => "http://www.google.com/schemas/sitemap-video/1.1"
      )
    end
  end

  describe "HEADER" do
    it "contains the expected header" do
      header = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:xhtml="http://www.w3.org/1999/xhtml"
          xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
          xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"
          xmlns:mobile="http://www.google.com/schemas/sitemap-mobile/1.0"
          xmlns:news="http://www.google.com/schemas/sitemap-news/0.9"
          xmlns:pagemap="http://www.google.com/schemas/sitemap-pagemap/1.0"
          xmlns:video="http://www.google.com/schemas/sitemap-video/1.1"
        >
      XML
      expect(described_class::HEADER).to eq(header)
    end
  end

  describe "FOOTER" do
    it "contains the expected footer" do
      expect(described_class::FOOTER).to eq("</urlset>")
    end
  end

  describe "FOOTER_BYTESIZE" do
    it "contains the expected footer bytesize" do
      expect(described_class::FOOTER_BYTESIZE).to eq(9)
    end
  end

  describe "#initialize" do
    it "initializes the content, links_count, and news_count" do
      instance = described_class.new

      expect(instance.content.string).to eq(described_class::HEADER)
      expect(instance.links_count).to eq(0)
      expect(instance.news_count).to eq(0)
    end
  end

  describe "#add" do
    it "adds a URL to the content" do
      instance = described_class.new
      instance.add("http://example.com")

      expect(instance.content.string).to include("<url>")
      expect(instance.links_count).to eq(1)
    end

    it "raises a FullSitemapError if the URL does not fit" do
      instance = described_class.new
      instance.instance_variable_set(:@links_count, SiteMaps::MAX_LENGTH[:links])

      expect do
        instance.add("http://example.com")
      end.to raise_error(SiteMaps::FullSitemapError)
    end

    context "when the URL is a news URL" do
      it "increments the news_count" do
        instance = described_class.new
        instance.add("http://example.com", news: {publication: "Example"})

        expect(instance.news_count).to eq(1)
      end

      it "does not increment the news_count if the URL is not a news URL" do
        instance = described_class.new
        instance.add("http://example.com")

        expect(instance.news_count).to eq(0)
      end

      it "raises a FullSitemapError if the URL does not fit" do
        instance = described_class.new
        instance.instance_variable_set(:@news_count, SiteMaps::MAX_LENGTH[:news])

        expect do
          instance.add("http://example.com", news: {publication: "Example"})
        end.to raise_error(SiteMaps::FullSitemapError)
      end
    end
  end

  describe "#finalize!" do
    it "finalizes the content and returns it as a string" do
      instance = described_class.new
      instance.add("http://example.com")
      content = instance.finalize!

      expect(content).to include("<url>")
      expect(content).to include("</urlset>")
      expect(content).to be_frozen
    end
  end

  describe "#to_xml" do
    it "returns the content as a string" do
      instance = described_class.new
      instance.add("http://example.com")
      content = instance.to_xml

      expect(content).to include("<url>")
      expect(content).to include("</urlset>")
      expect(content).not_to be_frozen
    end

    it "returns the finalized content as a string" do
      instance = described_class.new
      instance.add("http://example.com")
      instance.finalize!
      content = instance.to_xml

      expect(content).to include("<url>")
      expect(content).to include("</urlset>")
      expect(content).to be_frozen
    end
  end

  describe "#finalized?" do
    it "returns true if the content is finalized" do
      instance = described_class.new
      instance.add("http://example.com")
      instance.finalize!

      expect(instance).to be_finalized
    end

    it "returns false if the content is not finalized" do
      instance = described_class.new
      instance.add("http://example.com")

      expect(instance).not_to be_finalized
    end
  end

  describe "#empty?" do
    it "returns true if the links_count is zero" do
      instance = described_class.new

      expect(instance).to be_empty
    end

    it "returns false if the links_count is not zero" do
      instance = described_class.new
      instance.add("http://example.com")

      expect(instance).not_to be_empty
    end
  end

  describe "#last_modified" do
    it "returns the last modified date" do
      instance = described_class.new
      instance.add("http://example.com", lastmod: Time.new(2021, 1, 1))

      expect(instance.last_modified).to eq(Time.new(2021, 1, 1))
    end

    it "returns the current time if no last modified date is set" do
      instance = described_class.new

      expect(instance.last_modified).to be_within(1).of(Time.now)
    end

    it "returns the greatest last modified date" do
      instance = described_class.new
      instance.add("http://example.com", lastmod: Time.new(2021, 2, 1))
      instance.add("http://example.com", lastmod: Time.new(2021, 2, 2))
      instance.add("http://example.com", lastmod: Time.new(2021, 1, 1))

      expect(instance.last_modified).to eq(Time.new(2021, 2, 2))
    end
  end
end
