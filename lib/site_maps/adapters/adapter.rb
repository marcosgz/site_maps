# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    attr_reader :url_set

    def initialize(**options, &block)
      @config = SiteMaps.config.becomes(self.class::Config, **options)
      @url_set = SiteMaps::Sitemap::URLSet.new
      yield(self) if block
    end

    def config
      yield(@config) if block_given?
      @config
    end
    alias_method :configure, :config

    def sitemap_index
      @sitemap_index ||= self.class::SitemapIndex.new(config)
    end

    def add(path, params: nil, **options)
      link = build_link(path, params)
      url_set.add(link, **options)
    rescue SiteMaps::FullSitemapError
      finalize_url_set
    end

    def finalize_url_set
      raw_data = url_set.finalize
      write(location, raw_data)
      sitemap_index.add(location, lastmod: Time.now)
      @url_set = SiteMaps::Sitemap::UrlSet.new
    end

    protected

    def build_link(path, params)
      if config.host.nil?
        raise SiteMaps::ConfigurationError, <<~ERROR
          You must set a host in your configuration to use the add method.

          Example:
            SiteMaps.configure do |config|
              config.host = "https://example.com"
            end
        ERROR
      end
      SiteMaps::Sitemap::Link.new(config.host, path, params)
    end

    def write(location, raw_data)
      raise NotImplementedError
    end
  end
end
