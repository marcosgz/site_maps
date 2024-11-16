# frozen_string_literal: true

module SiteMaps
  class AtomicRepository
    attr_reader :main_url

    def initialize(main_url)
      @main_url = main_url
      @preloaded_index_links = Concurrent::Hash.new
      @generated_urls = Concurrent::Hash.new
    end

    def generate_url(raw_location)
      location = IncrementalLocation.new(main_url, raw_location)
      (@generated_urls[location.relative_directory] ||= location).next.url
    end
  end
end
