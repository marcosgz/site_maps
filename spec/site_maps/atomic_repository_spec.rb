# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::AtomicRepository do
  let(:main_url) { "https://example.com/my-site/sitemap.xml" }
  let(:repository) { described_class.new(main_url) }

  describe "#initialize" do
    it "initialize the repository" do
      expect(repository.main_url).to eq(main_url)
    end

    it "initialize the preloaded index links" do
      expect(repository.preloaded_index_links).to be_a(Concurrent::Array)
    end
  end

  describe "#generate_url" do
    it "thread-safely generate a new URL" do
      arr = Concurrent::Array.new
      threads = Array.new(4) do
        Thread.new do
          arr.push(repository.generate_url("https://example.com/my-site/group/sitemap.xml"))
        end
      end

      other_loc = repository.generate_url("https://example.com/my-site/2024/sitemap.xml")

      threads.each(&:join)

      expect(arr).to contain_exactly(
        "https://example.com/my-site/group/sitemap1.xml",
        "https://example.com/my-site/group/sitemap2.xml",
        "https://example.com/my-site/group/sitemap3.xml",
        "https://example.com/my-site/group/sitemap4.xml"
      )
      expect(other_loc).to eq("https://example.com/my-site/2024/sitemap1.xml")
    end
  end

  describe "#remaining_index_links" do
    context "when there are no generated URLs" do
      it "returns an empty array" do
        expect(repository.remaining_index_links).to be_empty
      end
    end

    context "when there are generated URLs but no preloaded index links" do
      before do
        repository.generate_url("https://example.com/my-site/group/sitemap.xml")
      end

      it "returns and empty array" do
        expect(repository.remaining_index_links).to be_empty
      end
    end

    context "when there are preloaded index links but none have been generated" do
      before do
        repository.preloaded_index_links.push(
          SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/my-site/group/sitemap1.xml")
        )
      end

      it "returns the preloaded index links" do
        expect(repository.remaining_index_links.map(&:loc)).to contain_exactly(
          "https://example.com/my-site/group/sitemap1.xml"
        )
      end
    end

    context "when there are preloaded index links and some have been generated" do
      before do
        repository.preloaded_index_links.push(
          SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/my-site/group/sitemap1.xml"),
          SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/my-site/group/sitemap2.xml"),
          SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/my-site/sitemap1.xml"),
          SiteMaps::Builder::SitemapIndex::Item.new("https://example.com/sitemap1.xml")
        )
        repository.generate_url("https://example.com/my-site/group/sitemap.xml")
      end

      it "returns the remaining preloaded index links" do
        expect(repository.remaining_index_links.map(&:loc)).to contain_exactly(
          "https://example.com/my-site/sitemap1.xml",
          "https://example.com/sitemap1.xml"
        )
      end

      it "returns an empty array when all preloaded index links have been generated" do
        repository.generate_url("https://example.com/my-site/sitemap.xml")
        repository.generate_url("https://example.com/sitemap.xml")
        expect(repository.remaining_index_links).to be_empty
      end
    end
  end
end
