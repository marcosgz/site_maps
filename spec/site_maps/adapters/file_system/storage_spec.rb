# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::FileSystem::Storage do
  let(:location) { SiteMaps::Adapters::FileSystem::Location.new(root, url) }
  let(:root) { "/tmp/site_maps" }
  let(:url) { "http://example.com/2024/#{filename}" }
  let(:filename) { "sitemap-#{SecureRandom.hex(8)}.xml" }

  before do
    FileUtils.mkdir_p("/tmp/site_maps/2024")
  end

  after do
    FileUtils.rm_rf("/tmp/site_maps")
  end

  describe "#write" do
    subject(:write!) { described_class.new.write(location, data) }

    let(:data) { "<sitemap></sitemap>" }

    context "when the location is a directory" do
      it "writes the data to the location" do
        expect { write! }.to change { File.exist?(location.path) }.from(false).to(true)
        expect(File.read(location.path)).to eq(data)
      end
    end

    context "when the location is a gzipped file" do
      let(:filename) { "sitemap-#{SecureRandom.hex(8)}.xml.gz" }

      it "writes the data to the location" do
        expect { write! }.to change { File.exist?(location.path) }.from(false).to(true)
        expect(Zlib::GzipReader.open(location.path).read).to eq(data)
      end
    end

    context "when the location is not a directory" do
      let(:root) { "/tmp/site_maps/file" }
      let(:url) { "http://example.com/#{filename}" }

      before do
        FileUtils.touch(location.directory)
      end

      it "raises an error" do
        expect { write! }.to raise_error(SiteMaps::Error, "The path #{location.directory} is not a directory")
      end
    end
  end

  describe "#read" do
    subject(:read!) { described_class.new.read(location) }

    let(:data) { "<sitemap></sitemap>" }

    context "when the location is a plain file" do
      before do
        File.binwrite(location.path, data)
      end

      it "reads the data from the location" do
        expect(read!).to eq([data, {content_type: "application/xml"}])
      end
    end

    context "when the location is a gzipped file" do
      let(:filename) { "sitemap-#{SecureRandom.hex(8)}.xml.gz" }

      before do
        Zlib::GzipWriter.open(location.path) { |gz| gz.write(data) }
      end

      it "reads the data from the location" do
        expect(read!).to eq([data, {content_type: "application/gzip"}])
      end
    end

    context "when the location does not exist" do
      it "raises an error" do
        expect { read! }.to raise_error(SiteMaps::FileNotFoundError, "File not found: #{location.path}")
      end
    end
  end

  describe "#delete" do
    subject(:delete!) { described_class.new.delete(location) }

    context "when the location exists" do
      before do
        FileUtils.touch(location.path)
      end

      it "deletes the location" do
        expect { delete! }.to change { File.exist?(location.path) }.from(true).to(false)
      end
    end

    context "when the location is a gzipped file" do
      let(:filename) { "sitemap-#{SecureRandom.hex(8)}.xml.gz" }

      before do
        Zlib::GzipWriter.open(location.path) { |gz| gz.write("<sitemap></sitemap>") }
      end

      it "deletes the location" do
        expect { delete! }.to change { File.exist?(location.path) }.from(true).to(false)
      end
    end

    context "when the location does not exist" do
      it "raises an error" do
        expect { delete! }.to raise_error(SiteMaps::FileNotFoundError, "File not found: #{location.path}")
      end
    end
  end
end
