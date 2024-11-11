# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::AwsSdk::Config do
  describe "#initialize" do
    it "sets the default values" do
      config = described_class.new

      expect(config.host).to be_nil
      expect(config.directory).to eq("/tmp/sitemaps")
      expect(config.main_filename).to eq("sitemap.xml")
      expect(config.access_key_id).to be_nil
      expect(config.secret_access_key).to be_nil
      expect(config.region).to eq("us-east-1")
      expect(config.bucket).to be_nil
      expect(config.acl).to eq("public-read")
      expect(config.cache_control).to eq("private, max-age=0, no-cache")
      expect(config.aws_extra_options).to eq({})
    end

    it "sets the provided values" do
      config = described_class.new(
        host: "https://example.com",
        directory: "tmp",
        main_filename: "sitemap_index.xml.gz",
        access_key_id: "access_key_id",
        secret_access_key: "secret_access_key",
        region: "region",
        bucket: "bucket",
        acl: "acl",
        cache_control: "cache_control",
        extra_option: "extra_option"
      )

      expect(config.host).to eq("https://example.com")
      expect(config.directory).to eq("tmp")
      expect(config.main_filename).to eq("sitemap_index.xml.gz")
      expect(config.access_key_id).to eq("access_key_id")
      expect(config.secret_access_key).to eq("secret_access_key")
      expect(config.region).to eq("region")
      expect(config.bucket).to eq("bucket")
      expect(config.acl).to eq("acl")
      expect(config.cache_control).to eq("cache_control")
      expect(config.aws_extra_options).to eq(extra_option: "extra_option")
    end
  end
end
