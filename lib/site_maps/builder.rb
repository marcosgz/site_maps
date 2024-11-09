# frozen_string_literal: true

module SiteMaps
  class Builder
    attr_reader :paths

    def initialize
      @paths = []
    end

    def add(path, **options)
      paths << { path: path, options: options }
    end
  end
end
