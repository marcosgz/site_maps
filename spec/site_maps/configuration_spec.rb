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
  end
end
