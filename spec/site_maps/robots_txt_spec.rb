# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::RobotsTxt do
  describe ".sitemap_directive" do
    it "returns the Sitemap directive for a given URL" do
      expect(described_class.sitemap_directive("https://example.com/sitemap.xml"))
        .to eq("Sitemap: https://example.com/sitemap.xml")
    end

    it "uses the current adapter URL when no URL is provided" do
      SiteMaps.use(:noop) do
        config.url = "https://example.com/sitemap.xml"
      end

      expect(described_class.sitemap_directive).to eq("Sitemap: https://example.com/sitemap.xml")
    end

    it "raises when no URL and no adapter configured" do
      allow(SiteMaps).to receive(:current_adapter).and_return(nil)

      expect { described_class.sitemap_directive }.to raise_error(ArgumentError)
    end
  end

  describe ".render" do
    it "returns a complete robots.txt" do
      result = described_class.render(sitemap_url: "https://example.com/sitemap.xml")

      expect(result).to eq(<<~TXT)
        User-agent: *
        Allow: /
        Sitemap: https://example.com/sitemap.xml
      TXT
    end

    it "includes extra directives" do
      result = described_class.render(
        sitemap_url: "https://example.com/sitemap.xml",
        extra_directives: ["Disallow: /admin/"]
      )

      expect(result).to include("Disallow: /admin/")
      expect(result).to include("Sitemap: https://example.com/sitemap.xml")
    end
  end
end
