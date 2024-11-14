# frozen_string_literal: true

module SiteMaps
  class SitemapBuilder
    extend Forwardable

    def initialize(adapter:, location: nil)
      @adapter = adapter
      @url_set = SiteMaps::Sitemap::URLSet.new
      @location = IncrementalLocation.new(adapter.config.url, location)
    end

    def add(path, params: nil, **options)
      link = build_link(path, params)
      begin
        url_set.add(link, **options)
      rescue SiteMaps::FullSitemapError
        finalize_and_start_next_urlset!
        url_set.add(link, **options)
      end
    end

    def add_sitemap_index(url, lastmod: Time.now)
      sitemap_index.add(url, lastmod: lastmod)
    end

    def finalize!
      return if url_set.finalized?
      return if url_set.empty?

      raw_data = url_set.finalize!

      if adapter.maybe_inline_urlset? && sitemap_index.empty?
        adapter.write(location.main_url, raw_data, last_modified: url_set.last_modified)
      else
        sitemap_url = location.next.to_s
        adapter.write(sitemap_url, raw_data, last_modified: url_set.last_modified)
        add_sitemap_index(sitemap_url, lastmod: url_set.last_modified)
      end
    end

    protected

    attr_reader :url_set, :adapter, :location

    def_delegators :adapter, :sitemap_index, :config

    def finalize_and_start_next_urlset!
      raw_data = url_set.finalize!
      sitemap_url = location.next.to_s
      adapter.write(sitemap_url, raw_data, last_modified: url_set.last_modified)
      add_sitemap_index(sitemap_url, lastmod: url_set.last_modified)
      @url_set = SiteMaps::Sitemap::URLSet.new
    end

    def build_link(path, params)
      SiteMaps::Sitemap::Link.new(config.host, path, params)
    end
  end
end
