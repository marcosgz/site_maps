# frozen_string_literal: true

module SiteMaps::Sitemap
  class URLSet
    SCHEMAS = {
      "image" => "http://www.google.com/schemas/sitemap-image/1.1",
      "mobile" => "http://www.google.com/schemas/sitemap-mobile/1.0",
      "news" => "http://www.google.com/schemas/sitemap-news/0.9",
      "pagemap" => "http://www.google.com/schemas/sitemap-pagemap/1.0",
      "video" => "http://www.google.com/schemas/sitemap-video/1.1"
    }.freeze

    HEADER = <<~HEADER
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xhtml="http://www.w3.org/1999/xhtml"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
      #{SCHEMAS.map { |name, uri| "  xmlns:#{name}=\"#{uri}\"" }.join("\n")}
      >
    HEADER
    FOOTER = "</urlset>"
    FOOTER_BYTESIZE = FOOTER.bytesize

    attr_reader :content, :links_count, :news_count

    def initialize
      @content = StringIO.new
      @content.puts(HEADER)
      @links_count = 0
      @news_count = 0
    end

    def add(link, **options)
      url = SiteMaps::Sitemap::URL.new(link, **options)
      raise SiteMaps::FullSitemapError unless fit?(url)

      content.puts(url.to_xml)
      @links_count += 1
      @news_count += 1 if url.news?
      url
    end

    def finalize
      return if finalized?

      content.puts(FOOTER)
      @to_xml = content.string.freeze
      content.close
      @to_xml
    end

    def to_xml
      return content.string + FOOTER unless finalized?

      @to_xml
    end

    def finalized?
      defined?(@to_xml)
    end

    private

    def bytesize
      content.string.bytesize
    end

    # @param url [Builder::URL]
    def fit?(url)
      return false if links_count >= SiteMaps::MAX_LENGTH[:links]
      return false if url.news? && news_count >= SiteMaps::MAX_LENGTH[:news]

      (bytesize + url.bytesize + FOOTER_BYTESIZE) <= SiteMaps::MAX_FILESIZE
    end
  end
end
