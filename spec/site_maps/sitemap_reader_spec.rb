# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::SitemapReader do
  describe "#read" do
    context "when the location is a local XML file" do
      subject(:reader) { described_class.new(location) }

      let(:location) { fixture_path("sitemap.xml") }

      it "reads the file" do
        expect(reader.read).to include("urlset")
      end

      it "raises an error if the file does not exist" do
        reader = described_class.new("unknown.xml")

        expect { reader.read }.to raise_error(SiteMaps::SitemapReader::FileNotFoundError)
      end
    end

    context "when the location is a local gzipped XML file" do
      subject(:reader) { described_class.new(location) }

      let(:location) { fixture_path("sitemap.xml.gz") }

      it "reads the file" do
        expect(reader.read).to include("urlset")
      end

      it "raises an error if the file does not exist" do
        reader = described_class.new("unknown.xml.gz")

        expect { reader.read }.to raise_error(SiteMaps::SitemapReader::FileNotFoundError)
      end
    end

    context "when the location is a remote XML file" do
      subject(:reader) { described_class.new(location) }

      let(:location) { "https://example.com/sitemap.xml" }

      it "reads the file" do
        stub_request(:get, location).to_return(body: fixture_file("sitemap.xml"))

        expect(reader.read).to include("urlset")
      end

      it "raises an error if the file does not exist" do
        stub_request(:get, location).to_return(status: 404)

        expect { reader.read }.to raise_error(SiteMaps::SitemapReader::FileNotFoundError)
      end
    end

    context "when the location is a remote gzipped XML file" do
      subject(:reader) { described_class.new(location) }

      let(:location) { "https://example.com/sitemap.xml.gz" }

      it "reads the file" do
        stub_request(:get, location).to_return(body: fixture_file("sitemap.xml.gz"))

        expect(reader.read).to include("urlset")
      end

      it "raises an error if the file does not exist" do
        stub_request(:get, location).to_return(status: 404)

        expect { reader.read }.to raise_error(SiteMaps::SitemapReader::FileNotFoundError)
      end
    end
  end

  describe "#to_doc" do
    subject(:reader) { described_class.new(location) }

    let(:location) { fixture_path("sitemap.xml") }

    it "returns a Nokogiri document" do
      expect(reader.to_doc).to be_a(Nokogiri::XML::Document)
    end

    it "raises an error if the file does not exist" do
      reader = described_class.new("unknown.xml")

      expect { reader.to_doc }.to raise_error(SiteMaps::SitemapReader::FileNotFoundError)
    end
  end
end
