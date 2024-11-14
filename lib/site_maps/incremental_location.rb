# frozen_string_literal: true

module SiteMaps
  class IncrementalLocation
    FILENAME = "sitemap.xml"
    PLACEHOLDER = "%{index}"

    def initialize(main_url, process_location)
      @main_uri = URI(main_url)
      @process_url = normalize(process_location || @main_uri.to_s)
      @index = 0
    end

    def to_s(index: nil)
      index ||= @index
      process_url % {index: index}
    end

    def next
      @index += 1
      self
    end

    def main_url
      main_uri.to_s
    end

    private

    attr_reader :main_uri, :process_url

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
      # Add placeholder to the basename
      basename = File.basename(uri.path)
      basename.sub!(/[\.](xml|xml\.gz)$/, "#{PLACEHOLDER}.\\1")

      base = uri.dup.tap { |v| v.path = "" }.to_s

      File.join(base, File.join(File.dirname(uri.path), basename))
    end
  end
end
