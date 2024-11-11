# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Configuration do
  subject(:configuration) { described_class.new }

  it "has a host" do
    expect(configuration.host).to be_nil
  end

  it "has a main filename" do
    expect(configuration.main_filename).to eq("sitemap.xml")
  end

  it "has a directory" do
    expect(configuration.directory).to eq("/tmp/sitemaps")
  end

  context "when initialized with options" do
    subject(:configuration) do
      described_class.new(
        host: "https://example.com",
        main_filename: "sitemap_index.xml",
        directory: "tmp"
      )
    end

    it "has a host" do
      expect(configuration.host).to eq("https://example.com")
    end

    it "has a main filename" do
      expect(configuration.main_filename).to eq("sitemap_index.xml")
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

      expect(new_config.host).to eq(configuration.host)
      expect(new_config.main_filename).to eq(configuration.main_filename)
      expect(new_config.directory).to eq(configuration.directory)
    end

    it "allows overriding options" do
      new_config = configuration.becomes(config_class, host: "https://example.com")

      expect(new_config.host).to eq("https://example.com")
      expect(new_config.main_filename).to eq(configuration.main_filename)
      expect(new_config.directory).to eq(configuration.directory)
    end
  end

  describe "#to_h" do
    it "returns a hash of the configuration" do
      expect(configuration.to_h).to include(
        host: nil,
        main_filename: "sitemap.xml",
        directory: "/tmp/sitemaps"
      )
    end
  end
end
