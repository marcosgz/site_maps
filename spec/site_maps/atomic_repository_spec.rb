# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::AtomicRepository do
  let(:main_url) { "https://example.com/my-site/sitemap.xml" }
  let(:repository) { described_class.new(main_url) }

  describe "#initialize" do
    it "initialize the repository" do
      expect(repository.main_url).to eq(main_url)
    end
  end

  describe "#generate_url" do
    it "thread-safely generate a new URL" do
      arr = Concurrent::Array.new
      threads = 4.times.map do
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
        "https://example.com/my-site/group/sitemap4.xml",
      )
      expect(other_loc).to eq("https://example.com/my-site/2024/sitemap1.xml")
    end
  end
end
