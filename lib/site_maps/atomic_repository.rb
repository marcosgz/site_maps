# frozen_string_literal: true

module SiteMaps
  class AtomicRepository
    attr_reader :main_url, :preloaded_index_links

    def initialize(main_url)
      @main_url = main_url
      @preloaded_index_links = Concurrent::Array.new
      @generated_urls = Concurrent::Hash.new
    end

    def generate_url(raw_location)
      location = IncrementalLocation.new(main_url, raw_location)
      (@generated_urls[location.relative_directory] ||= location).next.url
    end

    def remaining_index_links
      preloaded_index_links.reject do |link|
        @generated_urls.key?(link.relative_directory)
      end
    end
  end
end
