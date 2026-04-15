# frozen_string_literal: true

require_relative "site_maps/version"

require "builder"
require "logger"
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
loader.inflector.inflect "xsl_stylesheet" => "XSLStylesheet"
loader.log! if ENV["DEBUG_ZEITWERK"]
loader.setup

module SiteMaps
  MAX_LENGTH = {
    links: 50_000,
    images: 1_000,
    news: 1_000
  }
  MAX_FILESIZE = 50_000_000 # bytes
  DEFAULT_LOGGER = ::Logger.new($stdout)

  Error = Class.new(StandardError)
  AdapterNotFound = Class.new(Error)
  AdapterNotSetError = Class.new(Error)
  FileNotFoundError = Class.new(Error)
  FullSitemapError = Class.new(Error)
  ConfigurationError = Class.new(Error)

  SCOPE_KEY = :__site_maps_scope__

  @mutex = Mutex.new

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
      instance = adapter_class.new(**options, &block)
      if (scope = Thread.current[SCOPE_KEY])
        scope[:adapter] = instance
      else
        @current_adapter = instance
      end
      instance
    end

    # Register a context-aware sitemap definition. The block is stored and
    # called when {.generate} is invoked with a `context:` argument.
    #
    # Example:
    #   # config/sitemap.rb
    #   SiteMaps.define do |site|
    #     use(:file_system) do
    #       config.url = "https://#{site.domain}/sitemap.xml"
    #       process { |s| site.pages.each { |p| s.add(p.path) } }
    #     end
    #   end
    #
    #   # Usage:
    #   SiteMaps.generate(config_file: "config/sitemap.rb", context: site).enqueue_all.run
    #
    # @param block [Proc] Receives the context argument(s) passed to {.generate}
    def define(&block)
      if (scope = Thread.current[SCOPE_KEY])
        scope[:definition] = block
      else
        @definition = block
      end
    end

    def config
      @mutex.synchronize { @config ||= Configuration.new }
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
    # For multi-tenant / context-aware configurations, the config file can
    # use {.define} and pass runtime context via the `context:` kwarg:
    #
    # Example:
    #   SiteMaps.generate(config_file: "config/sitemap.rb", context: site)
    #     .enqueue_all
    #     .run
    #
    # @param config_file [String] The path to a configuration file
    # @param context [Object, Array] Value(s) passed to the block registered
    #   via {.define}. Arrays are splatted as positional arguments.
    # @param options [Hash] Options to pass to the runner
    # @return [Runner] An instance of the runner
    def generate(config_file: nil, context: nil, **options)
      adapter = nil
      if config_file
        previous_scope = Thread.current[SCOPE_KEY]
        scope = {adapter: nil, definition: nil}
        Thread.current[SCOPE_KEY] = scope
        begin
          load(config_file)
          if scope[:definition]
            args = context.is_a?(Array) ? context : [context].compact
            instance_exec(*args, &scope[:definition])
          end
          adapter = scope[:adapter]
        ensure
          Thread.current[SCOPE_KEY] = previous_scope
        end
        # Preserve backward-compat: expose the generated adapter through
        # the `current_adapter` singleton for single-tenant callers. In
        # multi-tenant concurrent use, last-writer-wins — each Runner still
        # gets its own isolated adapter from the thread-local scope above.
        @current_adapter = adapter if adapter
      else
        adapter = current_adapter
      end
      raise AdapterNotSetError, "No adapter set. Use SiteMaps.use to set an adapter" unless adapter

      Runner.new(adapter, **options)
    end

    def logger
      @mutex.synchronize { @logger ||= DEFAULT_LOGGER }
    end
  end
end

if defined?(::Rails)
  require_relative "site_maps/railtie"
end
