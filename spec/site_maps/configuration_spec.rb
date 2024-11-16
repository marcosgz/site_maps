# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Configuration do
  subject(:configuration) { described_class.new }

  describe ".attribute" do
    it "defines an attribute" do
      klass = Class.new(described_class) do
        attribute :custom
      end

      expect(klass.new).to respond_to(:custom)
      expect(klass.new).to respond_to(:custom=)
      expect(klass.new).to respond_to(:custom?)
    end

    it "defines a default value" do
      klass = Class.new(described_class) do
        attribute :custom, default: "default"
      end

      expect(klass.new.custom).to eq("default")
    end

    it "resolves the proc value" do
      klass = Class.new(described_class) do
        attribute :custom, default: -> { 1 + 2 }
      end

      expect(klass.new.custom).to eq(3)
    end

    it "allows to set nil as value for the attribute with default" do
      klass = Class.new(described_class) do
        attribute :custom, default: "default"
      end

      instance = klass.new(custom: nil)
      expect(instance.custom).to be_nil
    end
  end

  it "has a default directory" do
    expect(configuration.directory).to eq("/tmp/sitemaps")
  end

  context "when initialized with options" do
    subject(:configuration) do
      described_class.new(
        url: "https://example.com/sitemap.xml",
        directory: "tmp"
      )
    end

    it "has a url" do
      expect(configuration.url).to eq("https://example.com/sitemap.xml")
    end

    it "has a directory" do
      expect(configuration.directory).to eq("tmp")
    end

    context "when passing unknown attribute" do
      it "raises ConfigurationError error" do
        expect {
          described_class.new(undefined: "value")
        }.to raise_error(SiteMaps::ConfigurationError)
      end
    end
  end

  describe "#becomes" do
    let(:config_class) do
      Class.new(described_class)
    end

    it "returns a new instance of the class with the same options" do
      new_config = configuration.becomes(config_class)

      expect(new_config.directory).to eq(configuration.directory)
    end

    it "allows overriding options" do
      new_config = configuration.becomes(config_class, url: "https://example.com/sitemap.xml")

      expect(new_config.url).to eq("https://example.com/sitemap.xml")
      expect(new_config.directory).to eq(configuration.directory)
    end
  end

  describe "#to_h" do
    it "returns a hash of the configuration" do
      configuration.url = "https://example.com/sitemap.xml"
      expect(configuration.to_h).to include(
        url: "https://example.com/sitemap.xml",
        directory: "/tmp/sitemaps"
      )
    end
  end

  # describe "#host" do
  #   it "returns the host from the url" do
  #     configuration.url = "https://example.com/sitemap.xml"
  #     expect(configuration.host).to eq("example.com")
  #   end

  #   context "when the url is not set" do
  #     it "raises an error" do
  #       configuration.url = nil
  #       expect { configuration.host }.to raise_error(SiteMaps::ConfigurationError)
  #     end
  #   end
  # end

  describe "#local_sitemap_path" do
    it "returns the local sitemap path" do
      configuration.url = "https://example.com/sitemap.xml"
      expect(configuration.local_sitemap_path).to eq(Pathname.new("/tmp/sitemaps/sitemap.xml"))
    end
  end

  describe "#read_index_sitemaps" do
    context "when the local sitemap file exists with a urlset" do
      before do
        configuration.directory = fixture_root
        configuration.url = "https://example.com/sitemap.xml"
      end

      it "returns and empty array" do
        expect(configuration.read_index_sitemaps).to eq([])
      end
    end

    context "when the local sitemap file exists with a sitemapindex" do
      before do
        configuration.directory = fixture_root
        configuration.url = "https://example.com/sitemap_index.xml"
      end

      it "returns the sitemap index urls" do
        expect(configuration.read_index_sitemaps).to contain_exactly(
          SiteMaps::Sitemap::SitemapIndex::Item.new("http://example.com/sitemap1.xml.gz", "2024-07-01T03:37:09-05:00"),
          SiteMaps::Sitemap::SitemapIndex::Item.new("http://example.com/sitemap2.xml.gz", "2024-07-01T03:37:10-05:00")
        )
      end
    end

    context "when the local sitemap file does not exist" do
      before do
        configuration.directory = fixture_root
        configuration.url = "https://example.com/missing-sitemap.xml"
      end

      it "returns an empty array" do
        stub_request(:get, "https://example.com/missing-sitemap.xml").to_return(status: 404)
        expect(configuration.read_index_sitemaps).to eq([])
      end
    end

    context "when the remote sitemap is a urlset" do
      before do
        configuration.url = "https://example.com/sitemap.xml"
      end

      it "returns an empty array" do
        stub_request(:get, "https://example.com/sitemap.xml").to_return(body: fixture_file("sitemap.xml"))

        expect(configuration.read_index_sitemaps).to eq([])
      end
    end

    context "when the remote sitemap is a sitemapindex" do
      before do
        configuration.url = "https://example.com/sitemap_index.xml"
      end

      it "returns the sitemap index urls" do
        stub_request(:get, "https://example.com/sitemap_index.xml").to_return(body: fixture_file("sitemap_index.xml"))

        expect(configuration.read_index_sitemaps).to contain_exactly(
          SiteMaps::Sitemap::SitemapIndex::Item.new("http://example.com/sitemap1.xml.gz", "2024-07-01T03:37:09-05:00"),
          SiteMaps::Sitemap::SitemapIndex::Item.new("http://example.com/sitemap2.xml.gz", "2024-07-01T03:37:10-05:00")
        )
      end
    end
  end

  describe "#remote_sitemap_directory" do
    it "returns the relative directory" do
      config = described_class.new(url: "https://example.com/sitemap.xml")

      expect(config.remote_sitemap_directory).to eq("")
    end

    it "returns the relative directory with a path" do
      config = described_class.new(url: "https://example.com/path/to/sitemap.xml")

      expect(config.remote_sitemap_directory).to eq("path/to")
    end
  end

  describe "#base_uri" do
    let(:config) { described_class.new(url: "https://example.com/sitemap.xml?foo=1#bar") }

    it "returns the base url" do
      expect(config.base_uri.to_s).to eq("https://example.com")
    end
  end
end
