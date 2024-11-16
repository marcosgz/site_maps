# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::SitemapBuilder do
  subject(:builder) do
    described_class.new(adapter: adapter, location: location)
  end

  let(:adapter) do
    SiteMaps.use(:noop) do
      config.url = "https://example.com/sitemap.xml"
    end
  end
  let(:location) { nil }

  describe "#initialize" do
    it "sets the adapter" do
      expect(builder.send(:adapter)).to eq(adapter)
    end

    it "sets the url_set" do
      expect(builder.send(:url_set)).to be_a(SiteMaps::Sitemap::URLSet)
    end

    it "sets the location" do
      expect(builder.send(:location)).to eq(nil)
    end

    context "when the location is provided" do
      let(:location) { "group/sitemap.xml" }

      it "sets the location" do
        expect(builder.send(:location)).to eq("group/sitemap.xml")
      end
    end
  end

  describe "#add" do
    subject(:builder) do
      described_class.new(adapter: adapter)
    end

    let(:adapter) do
      SiteMaps.use(:noop) do
        config.url = "https://example.com/sitemap.xml"
      end
    end

    it "adds a link to the url_set" do
      builder.add("/path")

      expect(builder.send(:url_set).links_count).to eq(1)
    end

    context "when the url_set is full" do
      before do
        builder.send(:url_set).instance_variable_set(:@links_count, SiteMaps::MAX_LENGTH[:links])
      end

      it "finalizes the current url_set and adds link to the next one" do
        builder.add("/path")

        expect(builder.send(:url_set).links_count).to eq(1)
        expect(builder.send(:sitemap_index).sitemaps.count).to eq(1)
      end
    end
  end

  describe "#add_sitemap_index" do
    subject(:builder) do
      described_class.new(adapter: adapter)
    end

    let(:adapter) do
      SiteMaps.use(:noop) do
        config.url = "https://example.com/sitemap.xml"
      end
    end

    it "adds a sitemap index to the sitemap index" do
      builder.add_sitemap_index("https://external.com/sitemap1.xml")

      expect(builder.send(:sitemap_index).sitemaps.count).to eq(1)
      expect(builder.send(:sitemap_index).sitemaps.first.loc).to eq("https://external.com/sitemap1.xml")
    end
  end

  describe "#finalize!", freeze_at: [2024, 6, 24, 12, 30, 55]  do
    subject(:builder) do
      described_class.new(adapter: adapter)
    end

    context "when the url_set is empty" do
      it "does not write anything" do
        allow(adapter).to receive(:write)

        builder.finalize!

        expect(adapter).not_to have_received(:write)
      end
    end

    context "when the url_set is already finalized" do
      before do
        builder.send(:url_set).instance_variable_set(:@links_count, SiteMaps::MAX_LENGTH[:links])
        builder.send(:finalize_and_start_next_urlset!)
      end

      it "does not write anything" do
        expect(builder.send(:sitemap_index).sitemaps.count).to eq(1)
        allow(adapter).to receive(:write)

        builder.finalize!

        expect(adapter).not_to have_received(:write)
      end
    end

    context "when the adapter fit for inline urlset" do
      let(:adapter) do
        SiteMaps.use(:noop) do
          config.url = "https://example.com/sitemap.xml"
          process do |b|
            b.add("/path")
          end
        end
      end

      before do
        adapter.processes.each { |_k, p| p.call(builder) }
      end

      it "may write the url_set to the main url" do
        expect(adapter.send(:maybe_inline_urlset?)).to be(true)
      end

      it "writes the url_set to the main url" do
        allow(adapter).to receive(:write).and_call_original

        builder.finalize!

        expect(adapter).to have_received(:write).with("https://example.com/sitemap.xml", anything, last_modified: builder.send(:url_set).last_modified)
        expect(adapter.send(:sitemap_index).sitemaps.count).to eq(0)
        expect(builder.send(:url_set).links_count).to eq(1)
      end
    end

    context "when the adapter does not fit for inline urlset" do
      let(:adapter) do
        SiteMaps.use(:noop) do
          config.url = "https://example.com/sitemap.xml"
          process(:foo) do |b|
            b.add("/foo")
          end
          process(:bar) do |b|
            b.add("/bar")
          end
        end
      end

      before do
        adapter.processes.each { |_k, p| p.call(builder) }
      end

      it "does not write the url_set to the main url" do
        expect(adapter.send(:maybe_inline_urlset?)).to be(false)
      end

      it "writes the url_set to the next url" do
        allow(adapter).to receive(:write).and_call_original

        builder.finalize!

        expect(adapter).to have_received(:write).with("https://example.com/sitemap1.xml", anything, last_modified: Time.now)
        expect(adapter.send(:sitemap_index).sitemaps.count).to eq(1)
        expect(builder.send(:url_set).links_count).to eq(2)
      end
    end
  end
end
