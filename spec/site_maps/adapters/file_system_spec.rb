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
    end
  end

  after do
    FileUtils.rm_rf("/tmp/site_maps")
  end

  describe "#write" do
    subject(:write!) { adapter.write(url, data, **metadata) }

    let(:metadata) { { last_modified: Time.now } }
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

  describe "#delete" do
    subject(:delete!) { adapter.delete(url) }

    let(:url) { "http://example.com/2024/sitemap-#{SecureRandom.hex(8)}.xml" }
    let(:data) { "<sitemap></sitemap>" }
    let(:location) { SiteMaps::Adapters::FileSystem::Location.new(adapter.config.directory, url) }

    before do
      adapter.write(url, data)
    end

    it "delegate to the storage" do
      allow(adapter.send(:storage)).to receive(:delete).and_call_original

      delete!

      expect(adapter.send(:storage)).to have_received(:delete).with(location)
    end
  end

  describe "#process" do
    subject(:run!) { runner.run }

    let(:runner) do
      SiteMaps::Runner.new(adapter, max_threads: 4).enqueue_all
    end

    it "writes the sitemap with inline URLset" do
      expect(adapter.maybe_inline_urlset?).to be(true)

      expect {
        run!
      }.not_to change { adapter.sitemap_index.sitemaps.size }

      sitemap_file = File.join(adapter.config.directory, "my-site/sitemap.xml")
      expect(File.exist?(sitemap_file)).to be(true)
      doc = Nokogiri::XML(File.read(sitemap_file))
      expect(doc.css("urlset url").size).to eq(2)
    end

    context "when there are multiple processes" do
      before do
        adapter.process(:another) do |s|
          s.add("/contact.html")
        end
      end

      it "writes the sitemap file for each process and adds them to the sitemap index" do
        expect(adapter.maybe_inline_urlset?).to be(false)

        expect {
          run!
        }.to change { adapter.sitemap_index.sitemaps.size }.by(2)

        index = File.join(adapter.config.directory, "my-site/sitemap.xml")
        sitemap1 = File.join(adapter.config.directory, "my-site/sitemap1.xml")
        sitemap2 = File.join(adapter.config.directory, "my-site/sitemap2.xml")
        expect(File.exist?(index)).to be(true)
        expect(File.exist?(sitemap1)).to be(true)
        expect(File.exist?(sitemap2)).to be(true)

        idx_doc = Nokogiri::XML(File.read(index))
        doc1 = Nokogiri::XML(File.read(sitemap1))
        doc2 = Nokogiri::XML(File.read(sitemap2))
        expect(idx_doc.css("sitemapindex sitemap loc").map(&:text)).to contain_exactly(
          "https://example.com/my-site/sitemap1.xml",
          "https://example.com/my-site/sitemap2.xml",
        )
        expect([
          doc1.css("urlset url loc").map(&:text),
          doc2.css("urlset url loc").map(&:text),
        ]).to contain_exactly(
          contain_exactly("https://example.com/index.html", "https://example.com/about.html"),
          contain_exactly("https://example.com/contact.html"),
        )
      end
    end

    context "when with a dinamic process" do
      before do
        adapter.process(:year_posts, "posts/%{year}/sitemap.xml", year: 2024) do |s, year:|
          s.add("/posts/#{year}/headline.html")
        end
        expect(adapter).to receive(:fetch_sitemap_index_links).and_return([])
      end

      it "writes the sitemap file for each process and adds them to the sitemap index" do
        expect(adapter.maybe_inline_urlset?).to be(false)

        expect {
          run!
        }.to change { adapter.sitemap_index.sitemaps.size }.by(2)

        index = File.join(adapter.config.directory, "my-site/sitemap.xml")
        sitemap1 = File.join(adapter.config.directory, "my-site/sitemap1.xml")
        dinamic1 = File.join(adapter.config.directory, "my-site/posts/2024/sitemap1.xml")
        expect(File.exist?(index)).to be(true)
        expect(File.exist?(sitemap1)).to be(true)
        expect(File.exist?(dinamic1)).to be(true)

        idx_doc = Nokogiri::XML(File.read(index))
        doc1 = Nokogiri::XML(File.read(sitemap1))
        dinamic_doc1 = Nokogiri::XML(File.read(dinamic1))
        expect(idx_doc.css("sitemapindex sitemap loc").map(&:text)).to contain_exactly(
          "https://example.com/my-site/sitemap1.xml",
          "https://example.com/my-site/posts/2024/sitemap1.xml",
        )
        expect([
          doc1.css("urlset url loc").map(&:text),
          dinamic_doc1.css("urlset url loc").map(&:text),
        ]).to contain_exactly(
          contain_exactly("https://example.com/index.html", "https://example.com/about.html"),
          contain_exactly("https://example.com/posts/2024/headline.html"),
        )
      end
    end
  end
end
