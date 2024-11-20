# frozen_string_literal: true

module SiteMaps
  class SitemapBuilder
    extend Forwardable

    def initialize(adapter:, location: nil)
      @adapter = adapter
      @url_set = SiteMaps::Sitemap::URLSet.new
      @location = location
      @mutex = Mutex.new
    end

    def add(path, params: nil, **options)
      @mutex.synchronize do
        begin
          link = build_link(path, params)
          url_set.add(link, **options)
        rescue SiteMaps::FullSitemapError
          finalize_and_start_next_urlset!
          url_set.add(link, **options)
        end
      end
    end

    def add_sitemap_index(url, lastmod: Time.now)
      sitemap_index.add(url, lastmod: lastmod)
    end

    def finalize!
      return if url_set.finalized?
      return if url_set.empty?

      raw_data = url_set.finalize!

      SiteMaps::Notification.instrument('sitemaps.builder.finalize_urlset') do |payload|
        payload[:links_count] = url_set.links_count
        payload[:news_count] = url_set.news_count
        payload[:last_modified] = url_set.last_modified

        if adapter.maybe_inline_urlset? && sitemap_index.empty?
          payload[:url] = repo.main_url
          adapter.write(repo.main_url, raw_data, last_modified: url_set.last_modified)
        else
          sitemap_url = repo.generate_url(location)
          payload[:url] = sitemap_url
          adapter.write(sitemap_url, raw_data, last_modified: url_set.last_modified)
          add_sitemap_index(sitemap_url, lastmod: url_set.last_modified)
        end
      end
    end

    protected

    attr_reader :url_set, :adapter, :location

    def_delegators :adapter, :sitemap_index, :config, :repo

    def finalize_and_start_next_urlset!
      raw_data = url_set.finalize!
      SiteMaps::Notification.instrument('sitemaps.builder.finalize_urlset') do |payload|
        sitemap_url = repo.generate_url(location)
        payload[:url] = sitemap_url
        payload[:links_count] = url_set.links_count
        payload[:news_count] = url_set.news_count
        payload[:last_modified] = url_set.last_modified
        adapter.write(sitemap_url, raw_data, last_modified: url_set.last_modified)
        add_sitemap_index(sitemap_url, lastmod: url_set.last_modified)
      end
      @url_set = SiteMaps::Sitemap::URLSet.new
    end

    def build_link(path, params)
      SiteMaps::Sitemap::Link.new(config.base_uri, path, params)
    end
  end
end
