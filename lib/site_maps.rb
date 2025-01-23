# frozen_string_literal: true

require_relative "site_maps/version"

require "builder"
require "concurrent-ruby"
require "date"
require "fileutils"
require "forwardable"
require "rack/utils"
require "stringio"
require "time"
require "uri"
require "zeitwerk"
require "zlib"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/site-maps.rb")
loader.ignore("#{__dir__}/site_maps/tasks.rb")
loader.ignore("#{__dir__}/site_maps/cli.rb")
loader.inflector.inflect "cli" => "CLI"
loader.inflector.inflect "dsl" => "DSL"
loader.inflector.inflect "url_set" => "URLSet"
loader.inflector.inflect "url" => "URL"
loader.inflector.inflect "xml" => "XML"
loader.log! if ENV["DEBUG_ZEITWERK"]
loader.setup

module SiteMaps
  MAX_LENGTH = {
    links: 50_000,
    images: 1_000,
    news: 1_000
  }
  MAX_FILESIZE = 50_000_000 # bytes
  DEFAULT_LOGGER = Logger.new($stdout)

  Error = Class.new(StandardError)
  AdapterNotFound = Class.new(Error)
  AdapterNotSetError = Class.new(Error)
  FileNotFoundError = Class.new(Error)
  FullSitemapError = Class.new(Error)
  ConfigurationError = Class.new(Error)

  class << self
    attr_reader :current_adapter
    attr_writer :logger

    # @param adapter [Class, String, Symbol] The name of the adapter to use
    # @param options [Hash] Options to pass to the adapter. Note that these are adapter-specific
    # @param block [Proc] A block to pass to the adapter
    # @return [Object] An instance of the adapter
    def use(adapter, **options, &block)
      adapter_class = if adapter.is_a?(Class) # && adapter < Adapters::Adapter
        adapter
      else
        const_name = Primitive::String.new(adapter.to_s).classify
        begin
          Adapters.const_get(const_name)
        rescue NameError
          raise AdapterNotFound, "Adapter #{adapter.inspect} not found"
        end
      end
      @current_adapter = adapter_class.new(**options, &block)
    end

    def config
      @config ||= Configuration.new
      yield(@config) if block_given?
      @config
    end
    alias_method :configure, :config

    # Load and prepare a runner with the current adapter
    # Note that it won't start running until you call `#run` on the runner
    #
    # Example:
    #   SiteMaps.generate(config_file: "config/site_maps.rb", max_threads: 10)
    #     .enqueue_all
    #     .run
    #
    # You may also enqueue processes manually, specially those that are dynamic
    #
    # Example:
    #   SiteMaps.generate(config_file: "config/site_maps.rb", max_threads: 10)
    #     .enqueue(:monthly, year: 2020, month: 1)
    #     .enqueue(:monthly, year: 2020, month: 2)
    #     .enqueue_remaining # Enqueue all other non-enqueued processes
    #     .run
    #
    # @param config_file [String] The path to a configuration file
    # @param options [Hash] Options to pass to the runner
    # @return [Runner] An instance of the runner
    def generate(config_file: nil, **options)
      if config_file
        @current_adapter = nil
        load(config_file)
      end
      raise AdapterNotSetError, "No adapter set. Use SiteMaps.use to set an adapter" unless current_adapter

      Runner.new(current_adapter, **options)
    end

    def logger
      @logger ||= DEFAULT_LOGGER
    end
  end
end

if defined?(::Rails)
  require_relative "site_maps/railtie"
end
