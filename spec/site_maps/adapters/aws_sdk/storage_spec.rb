# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::AwsSdk::Storage do
  let(:config) do
    SiteMaps::Adapters::AwsSdk::Config.new(
      bucket: "example-bucket",
      region: "us-west-2",
      access_key_id: "access_key_id",
      secret_access_key: "secret_access_key",
      directory: "/tmp",
      acl: "public-read",
      cache_control: "max-age=3600"
    )
  end
  let(:s3_bucket) { instance_double(Aws::S3::Bucket) }
  let(:storage) { described_class.new(config) }

  before do
    allow(config).to receive(:s3_bucket).and_return(s3_bucket)
  end

  describe "#upload" do
    subject(:upload!) { storage.upload(location, **metadata) }

    let(:location) { SiteMaps::Adapters::AwsSdk::Location.new("/tmp", "http://example.com/sitemaps/2024/sitemap1.xml") }
    let(:metadata) { {} }

    it "uploads the file to S3" do
      obj = instance_double(Aws::S3::Object)
      expect(s3_bucket).to receive(:object).with("sitemaps/2024/sitemap1.xml").and_return(obj)
      expect(obj).to receive(:upload_file).with(
        "/tmp/sitemaps/2024/sitemap1.xml",
        acl: "public-read",
        cache_control: "max-age=3600",
        content_type: "application/xml"
      )

      upload!
    end
  end

  describe "#read" do
    subject(:read!) { storage.read(location) }

    let(:location) { SiteMaps::Adapters::AwsSdk::Location.new("/tmp", "http://example.com/sitemaps/2024/sitemap1.xml") }
    let(:obj) { instance_double(Aws::S3::Object) }
    let(:body) { instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new("<sitemap></sitemap>"), content_type: "application/xml") }

    before do
      allow(s3_bucket).to receive(:object).with("sitemaps/2024/sitemap1.xml").and_return(obj)
      allow(obj).to receive(:get).and_return(body)
    end

    it "reads the file from S3" do
      expect(read!).to eq(["<sitemap></sitemap>", {content_type: "application/xml"}])
      expect(obj).to have_received(:get)
    end

    context "when the file does not exist" do
      before do
        allow(obj).to receive(:get).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, "key"))
      end

      it "raises a FileNotFoundError" do
        expect { read! }.to raise_error(SiteMaps::FileNotFoundError, "File not found: sitemaps/2024/sitemap1.xml")
      end
    end
  end

  describe "#delete" do
    subject(:delete!) { storage.delete(location) }

    let(:location) { SiteMaps::Adapters::AwsSdk::Location.new("/tmp", "http://example.com/sitemaps/2024/sitemap1.xml") }
    let(:obj) { instance_double(Aws::S3::Object) }

    before do
      allow(s3_bucket).to receive(:object).with("sitemaps/2024/sitemap1.xml").and_return(obj)
      allow(obj).to receive(:delete)
    end

    it "deletes the file from S3" do
      delete!
      expect(obj).to have_received(:delete)
    end

    context "when the file does not exist" do
      before do
        allow(obj).to receive(:delete).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, "key"))
      end

      it "raises a FileNotFoundError" do
        expect { delete! }.to raise_error(SiteMaps::FileNotFoundError, "File not found: sitemaps/2024/sitemap1.xml")
      end
    end
  end
end
