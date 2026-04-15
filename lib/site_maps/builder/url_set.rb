# frozen_string_literal: true

module SiteMaps::Builder
  class URLSet
    SCHEMAS = {
      "image" => "http://www.google.com/schemas/sitemap-image/1.1",
      "mobile" => "http://www.google.com/schemas/sitemap-mobile/1.0",
      "news" => "http://www.google.com/schemas/sitemap-news/0.9",
      "pagemap" => "http://www.google.com/schemas/sitemap-pagemap/1.0",
      "video" => "http://www.google.com/schemas/sitemap-video/1.1"
    }.freeze

    XML_DECLARATION = %(<?xml version="1.0" encoding="UTF-8"?>)
    URLSET_OPEN = <<~URLSET_OPEN
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xhtml="http://www.w3.org/1999/xhtml"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
      #{SCHEMAS.map { |name, uri| "  xmlns:#{name}=\"#{uri}\"" }.join("\n")}
      >
    URLSET_OPEN
    HEADER = "#{XML_DECLARATION}\n#{URLSET_OPEN}"
    FOOTER = "</urlset>"
    FOOTER_BYTESIZE = FOOTER.bytesize

    attr_reader :content, :links_count, :news_count

    def initialize(max_links: SiteMaps::MAX_LENGTH[:links], emit_priority: true, emit_changefreq: true, xsl_url: nil)
      @content = StringIO.new
      if xsl_url
        @content.puts(XML_DECLARATION)
        @content.puts(XSLStylesheet.processing_instruction(xsl_url))
        @content.puts(URLSET_OPEN)
      else
        @content.puts(HEADER)
      end
      @links_count = 0
      @news_count = 0
      @last_modified = nil
      @max_links = max_links
      @emit_priority = emit_priority
      @emit_changefreq = emit_changefreq
    end

    def add(link, **options)
      raise SiteMaps::FullSitemapError if finalized?

      url = SiteMaps::Builder::URL.new(link, emit_priority: @emit_priority, emit_changefreq: @emit_changefreq, **options)
      raise SiteMaps::FullSitemapError unless fit?(url)

      content.puts(url.to_xml)
      @links_count += 1
      @news_count += 1 if url.news?
      if (lastmod = url.last_modified)
        @last_modified ||= lastmod
        @last_modified = lastmod if lastmod > @last_modified
      end
      url
    end

    def finalize!
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

    def empty?
      links_count.zero?
    end

    def last_modified
      @last_modified || Time.now
    end

    private

    def bytesize
      content.string.bytesize
    end

    # @param url [Builder::URL]
    def fit?(url)
      return false if links_count >= @max_links
      return false if url.news? && news_count >= SiteMaps::MAX_LENGTH[:news]

      (bytesize + url.bytesize + FOOTER_BYTESIZE) <= SiteMaps::MAX_FILESIZE
    end
  end
end
