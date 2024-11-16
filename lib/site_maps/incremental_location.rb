# frozen_string_literal: true

module SiteMaps
  class IncrementalLocation
    FILENAME = "sitemap.xml"
    PLACEHOLDER = "%{index}"

    def initialize(main_url, process_location)
      @main_uri = URI(main_url)
      @index = Concurrent::AtomicFixnum.new(0)
      normalize(process_location || @main_uri.to_s)
    end

    def url
      placeholder_url % {index: @index.value}
    end

    def next
      @index.increment
      self
    end

    def main_url
      main_uri.to_s
    end

    def relative_directory
      File.dirname(@uri.path).sub(%r{^/}, "")
    end

    private

    attr_reader :main_uri, :placeholder_url

    def base_url
      main_uri.dup.tap { |uri| uri.path = "" }
    end

    def base_dir
      File.dirname(main_uri.path)
    end

    def normalize(loc)
      uri = if %r{^https?://}.match?(loc)
        URI(loc)
      elsif loc.start_with?("/")
        main_uri.dup.tap { |uri| uri.path = loc }
      else
        main_uri.dup.tap { |uri| uri.path = File.join(base_dir, loc) }
      end
      unless %w[.xml .xml.gz].include?(File.extname(uri.path))
        uri.path = File.join(uri.path, FILENAME)
      end
      base = uri.dup.tap { |v| v.path = "" }.to_s
      basename = File.basename(uri.path)
      index_basename = basename.sub(/[\.](xml|xml\.gz)$/, "#{PLACEHOLDER}.\\1")

      @placeholder_url = File.join(base, File.join(File.dirname(uri.path), index_basename))
      @uri = URI(File.join(base, File.join(File.dirname(uri.path), basename)))
    end
  end
end
