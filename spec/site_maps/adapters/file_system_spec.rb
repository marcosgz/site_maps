# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::FileSystem do
  let(:adapter) do
    SiteMaps.use(:file_system) do
      configure do |config|
        config.url = "https://example.com/my-site/sitemap.xml"
        config.directory = "/tmp/site_maps/file_system"
      end

      process do |s|
        s.add("/index.html")
        s.add("/about.html")
      end

      categories = %w[news sports entertainment]

      process(:categories) do |s|
        categories.each do |category|
          s.add("/#{category}.html")
        end
      end

      process(:posts, "posts/%{year}/sitemap.xml", year: 2024) do |s, year:|
        s.add("/posts/#{year}/index.html")
      end
    end
  end

  after do
    FileUtils.rm_rf("/tmp/site_maps")
  end

  describe "#write" do
    subject(:write!) { adapter.write(url, data) }

    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }
    let(:data) { "<sitemap></sitemap>" }
    let(:location) { SiteMaps::Adapters::FileSystem::Location.new(adapter.config.directory, url) }

    it "delegate to the storage" do
      allow(adapter.send(:storage)).to receive(:write).and_call_original

      write!

      expect(adapter.send(:storage)).to have_received(:write).with(location, data)
    end
  end

  describe "#read" do
    subject(:read!) { adapter.read(url) }

    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }
    let(:data) { "<sitemap></sitemap>" }
    let(:location) { SiteMaps::Adapters::FileSystem::Location.new(adapter.config.directory, url) }

    before do
      adapter.write(url, data)
    end

    it "delegate to the storage" do
      allow(adapter.send(:storage)).to receive(:read).and_call_original

      expect(read!).to eq([data, { content_type: "application/xml" }])

      expect(adapter.send(:storage)).to have_received(:read).with(location)
    end
  end
end
