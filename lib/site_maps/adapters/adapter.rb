# frozen_string_literal: true

module SiteMaps::Adapters
  class Adapter
    attr_reader :options

    def initialize(**options, &block)
      @options = options
      @block = block
    end
  end
end
