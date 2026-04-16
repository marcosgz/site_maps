# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    extend Forwardable

    class << self
      def config_class
        return SiteMaps::Configuration unless defined?(self::Config)

        self::Config
      end
    end

    def_delegators :config, :fetch_sitemap_index_links
    attr_reader :sitemap_index, :processes, :process_mixins

    def initialize(**options, &block)
      @config = SiteMaps.config.becomes(self.class.config_class, **options)
      @processes = Concurrent::Hash.new
      @process_mixins = Concurrent::Array.new
      reset!
      instance_exec(&block) if block
    end

    # @abstract
    # @param [String] url The remote URL to write to
    # @param [String] raw_data The raw data to write
    # @return [void]
    # @raise [SiteMaps::Error] if the write operation fails
    def write(_url, _raw_data, **_kwargs)
      raise NotImplementedError
    end

    # @abstract
    # @param [String] url The remote URL to read from
    # @return [Array<String, Hash>] The raw data and metadata
    # @raise [SiteMaps::FileNotFoundError] if the file does not exist
    def read(_url)
      raise NotImplementedError
    end

    # @abstract
    # @param [String] url The remote URL to delete
    # @return [void]
    # @raise [SiteMaps::FileNotFoundError] if the file does not exist
    def delete(_url)
      raise NotImplementedError
    end

    def config
      yield(@config) if block_given?
      @config
    end
    alias_method :configure, :config

    def process(name = :default, location = nil, **kwargs, &block)
      name = name.to_sym
      raise ArgumentError, "Process #{name} already defined" if @processes.key?(name)

      @processes[name] = SiteMaps::Process.new(name, location, kwargs, block)
    end

    def external_sitemap(url, lastmod: nil)
      @external_sitemaps ||= Concurrent::Array.new
      @external_sitemaps << SiteMaps::Builder::SitemapIndex::Item.new(url, lastmod)
    end

    def external_sitemaps
      @external_sitemaps || []
    end

    def maybe_inline_urlset?
      @processes.size == 1 && @processes.first.last.static? && external_sitemaps.empty?
    end

    def repo
      @repo ||= SiteMaps::AtomicRepository.new(config.url)
    end

    def extend_processes_with(mod)
      @process_mixins << mod
    end

    def url_filter(&block)
      if block
        @url_filters ||= Concurrent::Array.new
        @url_filters << block
      end
      @url_filters || []
    end

    def apply_url_filters(link, options)
      url = link.respond_to?(:to_s) ? link.to_s : link
      url_filter.each do |filter|
        result = filter.call(url, options)
        return nil if result == false

        options = result if result.is_a?(Hash)
      end
      options
    end

    def reset!
      xsl_url = config.respond_to?(:xsl_index_stylesheet_url) ? config.xsl_index_stylesheet_url : nil
      @sitemap_index = SiteMaps::Builder::SitemapIndex.new(xsl_url: xsl_url)
      @repo = nil
    end
  end
end
