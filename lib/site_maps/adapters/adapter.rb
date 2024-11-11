# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    attr_reader :url_set

    def initialize(**options, &block)
      @config = SiteMaps.config.becomes(config_class, **options)
      @url_set = SiteMaps::Sitemap::URLSet.new
      @groups = {}
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

    def group(group_name, rel_path, &block)
      @groups[group_name] = {
        url: File.join(config.remote_sitemap_directory, rel_path),
        block: block,
      }
    end

    protected

    def build_link(path, params)
      SiteMaps::Sitemap::Link.new(config.host, path, params)
    end

    def write(location, raw_data)
      raise NotImplementedError
    end

    def config_class
      return SiteMaps::Configuration unless defined?(self.class::Config)

      self.class::Config
    end
  end
end
