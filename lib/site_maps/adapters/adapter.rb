# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    class << self
      def config_class
        return SiteMaps::Configuration unless defined?(self::Config)

        self::Config
      end
    end

    attr_reader :sitemap_index, :processes

    def initialize(**options, &block)
      @config = SiteMaps.config.becomes(self.class.config_class, **options)
      @sitemap_index = SiteMaps::Sitemap::SitemapIndex.new

      @processes = Concurrent::Hash.new
      instance_exec(&block) if block
    end

    # @abstract
    # @param [String] url The remote URL to write to
    # @param [String] raw_data The raw data to write
    # @return [void]
    # @raise [SiteMaps::Error] if the write operation fails
    def write(_url, _raw_data)
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

    def maybe_inline_urlset?
      @processes.size == 1 && @processes.first.last.static?
    end
  end
end
