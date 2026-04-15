# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Ping do
  describe ".ping" do
    let(:sitemap_url) { "https://example.com/sitemap.xml" }
    let(:encoded_url) { ERB::Util.url_encode(sitemap_url) }

    it "pings Bing by default" do
      stub_request(:get, "https://www.bing.com/ping?sitemap=#{encoded_url}")
        .to_return(status: 200)

      results = described_class.ping(sitemap_url)

      expect(results[:bing][:status]).to eq(200)
    end

    it "pings custom engines" do
      custom_engines = {
        custom: "https://search.example.com/ping?url=%{url}"
      }

      stub_request(:get, "https://search.example.com/ping?url=#{encoded_url}")
        .to_return(status: 200)

      results = described_class.ping(sitemap_url, engines: custom_engines)

      expect(results[:custom][:status]).to eq(200)
    end

    it "handles network errors gracefully" do
      stub_request(:get, "https://www.bing.com/ping?sitemap=#{encoded_url}")
        .to_raise(Errno::ECONNREFUSED)

      results = described_class.ping(sitemap_url)

      expect(results[:bing][:status]).to be_nil
      expect(results[:bing][:error]).to be_a(String)
    end
  end

  describe ".default_engines" do
    it "returns the default engines hash" do
      expect(described_class.default_engines).to have_key(:bing)
    end
  end
end
