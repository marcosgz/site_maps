# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::AwsSdk::Config do
  describe "#initialize" do
    before do
      stub_const("ENV", {})
    end

    it "sets the default values" do
      config = described_class.new

      expect(config.instance_variable_get(:@url)).to be_nil
      expect(config.directory).to eq("/tmp/sitemaps")
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
        url: "https://example.com/sitemap.xml",
        directory: "tmp",
        access_key_id: "access_key_id",
        secret_access_key: "secret_access_key",
        region: "region",
        bucket: "bucket",
        acl: "acl",
        cache_control: "cache_control",
        extra_option: "extra_option"
      )

      expect(config.url).to eq("https://example.com/sitemap.xml")
      expect(config.directory).to eq("tmp")
      expect(config.access_key_id).to eq("access_key_id")
      expect(config.secret_access_key).to eq("secret_access_key")
      expect(config.region).to eq("region")
      expect(config.bucket).to eq("bucket")
      expect(config.acl).to eq("acl")
      expect(config.cache_control).to eq("cache_control")
      expect(config.aws_extra_options).to eq(extra_option: "extra_option")
    end
  end

  describe "#s3_resource" do
    it "returns an Aws::S3::Resource" do
      config = described_class.new(
        access_key_id: "access_key",
        secret_access_key: "secret_access_key",
        bucket: "my-bucket"
      )

      expect(config.s3_resource).to be_a(Aws::S3::Resource)
    end
  end

  describe "#inspect" do
    it "removes secret_access_key from inspect" do
      config = described_class.new(
        access_key_id: "access_key_id",
        secret_access_key: "secret_access_key",
        region: "region",
        bucket: "bucket"
      )

      expect(config.inspect).not_to include("secret_access_key")
    end
  end
end
