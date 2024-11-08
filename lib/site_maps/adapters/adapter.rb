# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    attr_reader :options, :config, :builder

    def initialize(**options, &block)
      @options = options
      @builder = SiteMaps::Builder.new
      @config = SiteMaps::Configuration.new
      block.call(@builder) if block_given?
    end

    def add(path, **options)
      builder.add(path, **options)
    end

    def configure(&block)
      @config.instance_eval(&block)
    end
  end
end
