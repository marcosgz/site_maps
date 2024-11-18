# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::AwsSdk do
  let(:adapter) do
    SiteMaps.use(:aws_sdk) do
      configure do |config|
        config.url = "https://example.com/my-site/sitemap.xml"
        config.directory = "/tmp/site_maps/aws_sdk"
      end

      process do |s|
        s.add("/index.html")
        s.add("/about.html")
      end
    end
  end

  after do
    FileUtils.rm_rf("/tmp/site_maps")
  end

  describe "#read" do
    subject(:read!) { adapter.read(url) }

    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }
    let(:data) { "<sitemap></sitemap>" }

    it "delegate to the storage" do
      metadata = {
        content_type: "application/xml",
        last_modified: Time.now
      }
      expect(adapter.send(:s3_storage)).to receive(:read).with(
        an_instance_of(SiteMaps::Adapters::AwsSdk::Location)
      ).and_return([
        data,
        metadata
      ])

      expect(read!).to eq([data, metadata])
    end
  end

  describe "#write" do
    subject(:write!) { adapter.write(url, data, **metadata) }

    let(:metadata) { {last_modified: Time.now} }
    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }
    let(:data) { "<sitemap></sitemap>" }

    it "delegate to the storage" do
      expect(adapter.send(:local_storage)).to receive(:write).with(
        an_instance_of(SiteMaps::Adapters::AwsSdk::Location),
        data
      )
      expect(adapter.send(:s3_storage)).to receive(:upload).with(
        an_instance_of(SiteMaps::Adapters::AwsSdk::Location),
        metadata
      )

      write!
    end
  end

  describe "#delete" do
    subject(:delete!) { adapter.delete(url) }

    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }

    it "delegate to the storage" do
      expect(adapter.send(:s3_storage)).to receive(:delete).with(
        an_instance_of(SiteMaps::Adapters::AwsSdk::Location)
      )

      delete!
    end
  end
end
