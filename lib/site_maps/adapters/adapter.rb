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

    SITEMAP_ENTRY_RE = %r{<sitemap>(.*?)</sitemap>}m
    LOC_RE = %r{<loc>\s*(.*?)\s*</loc>}m
    LASTMOD_RE = %r{<lastmod>\s*(.*?)\s*</lastmod>}m
    XML_ENTITIES = {"&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => '"', "&apos;" => "'"}.freeze

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

    # @abstract
    # @return [Array<SiteMaps::Builder::SitemapIndex::Item>] every sitemap file stored under the sitemap directory
    # @raise [NotImplementedError] if the adapter can not list its storage
    def list_sitemaps
      raise NotImplementedError, "#{self.class} does not support listing stored sitemaps"
    end

    # Reads the current sitemap index straight from the adapter storage.
    # Adapters without a #read implementation fall back to fetching the index URL.
    #
    # @return [Array<SiteMaps::Builder::SitemapIndex::Item>]
    def fetch_sitemap_index_links
      raw_data, metadata = read(config.url)
      return [] if raw_data.nil?

      parse_sitemap_index(decompress(raw_data, metadata))
    rescue SiteMaps::FileNotFoundError
      []
    rescue NotImplementedError
      config.fetch_sitemap_index_links
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

    private

    def parse_sitemap_index(xml)
      xml.scan(SITEMAP_ENTRY_RE).filter_map do |(entry)|
        loc = entry[LOC_RE, 1]
        next if loc.nil? || loc.empty?

        SiteMaps::Builder::SitemapIndex::Item.new(loc.gsub(/&(?:amp|lt|gt|quot|apos);/, XML_ENTITIES), entry[LASTMOD_RE, 1])
      end
    end

    def decompress(raw_data, metadata)
      return raw_data unless metadata.is_a?(Hash) && metadata[:content_type] == "application/gzip"

      Zlib::GzipReader.new(StringIO.new(raw_data)).read
    rescue Zlib::GzipFile::Error
      raw_data
    end
  end
end
