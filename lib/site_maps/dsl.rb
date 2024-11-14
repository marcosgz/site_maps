# frozen_string_literal: true

module SiteMaps
  # This class is the main entry point for the DSL. It is responsible for
  # receiving the user adapter, configuration and groups of sitemap links
  # that will be generated in parallel.
  class DSL
    attr_reader :config

    def initialize(adapter_class, max_threads: 1, **options, &block)
      @config = adapter_class.config_class.new(**options)
      @__adapter_class = adapter_class
      @__linksets = {}

      instance_exec(&block) if block

      start(max_threads: max_threads)
    end

    def configure
      yield(@config) if block_given?
      @config
    end

    def include_module(mod)
      extend(mod)
    end

    def linkset(*args, &block)
      group_name = (args.shift || :default).to_sym
      path = args.shift

      if @__linksets.key?(group_name)
        raise ArgumentError, "Linkset #{group_name} already defined"
      end

      @__linksets[group_name] = {
        path: path,
        block: block
      }
    end

    def incremental_linkset(name, *params, &block)
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} (#{__adapter_class})>"
    end
    alias_method :to_s, :inspect

    private

    def start(max_threads:)
    end
  end
end
