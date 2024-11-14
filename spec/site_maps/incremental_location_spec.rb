# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::IncrementalLocation do
  let(:index_url) { "https://example.com/sitemaps/sitemap_index.xml" }

  describe "#initialize" do
    it "sets the index_uri with the provided index_url" do
      location = described_class.new(index_url, "sitemap.xml")

      expect(location.instance_variable_get(:@main_uri).to_s).to eq(index_url)
    end

    it "sets the process_url with the provided process_location" do
      process_location = "sitemap.xml"
      location = described_class.new(index_url, process_location)

      expect(location.send(:process_url)).to eq("https://example.com/sitemaps/sitemap%{index}.xml")
    end

    context "when the process_location is a full URL" do
      let(:process_location) { "https://external.com/sitemap.xml" }

      it "sets the process_url with the provided process_location" do
        location = described_class.new(index_url, process_location)

        expect(location.send(:process_url)).to eq("https://external.com/sitemap%{index}.xml")
      end
    end

    context "when the process_location is a relative path" do
      let(:process_location) { "linkset/sitemap.xml" }

      it "sets the process_url with the provided process_location" do
        location = described_class.new(index_url, process_location)

        expect(location.send(:process_url)).to eq("https://example.com/sitemaps/linkset/sitemap%{index}.xml")
      end
    end

    context "when the process_location is a relative path with a leading slash" do
      let(:process_location) { "/linkset/sitemap.xml" }

      it "sets the process_url with the provided process_location" do
        location = described_class.new(index_url, process_location)

        expect(location.send(:process_url)).to eq("https://example.com/linkset/sitemap%{index}.xml")
      end
    end

    context "when the process_location is a relative path without a filename" do
      let(:process_location) { "linkset" }

      it "sets the process_url with the provided process_location" do
        location = described_class.new(index_url, process_location)

        expect(location.send(:process_url)).to eq("https://example.com/sitemaps/linkset/sitemap%{index}.xml")
      end
    end

    context "when the process_location is a relative path without a filename and with a leading slash" do
      let(:process_location) { "/linkset" }

      it "sets the process_url with the provided process_location" do
        location = described_class.new(index_url, process_location)

        expect(location.send(:process_url)).to eq("https://example.com/linkset/sitemap%{index}.xml")
      end
    end
  end

  describe "#to_s" do
    let(:location) { described_class.new(index_url, "sitemap.xml") }

    it "returns the process_url with the given index" do
      expect(location.to_s(index: 99)).to eq("https://example.com/sitemaps/sitemap99.xml")
    end

    it "returns the process_url with the default index" do
      expect(location.to_s).to eq("https://example.com/sitemaps/sitemap0.xml")
    end
  end

  describe "#next" do
    let(:location) { described_class.new(index_url, "sitemap.xml") }

    it "increments the index" do
      result = nil
      expect { result = location.next }.to change { location.instance_variable_get(:@index) }.from(0).to(1)
      expect(result).to eq(location)
    end
  end

  describe "#main_url" do
    let(:location) { described_class.new(index_url, "sitemap.xml") }

    it "returns the main URL" do
      expect(location.main_url).to eq("https://example.com/sitemaps/sitemap_index.xml")
    end
  end
end
