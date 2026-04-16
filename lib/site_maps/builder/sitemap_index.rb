# frozen_string_literal: true

module SiteMaps::Builder
  class SitemapIndex
    XML_DECLARATION = %(<?xml version="1.0" encoding="UTF-8"?>)
    SITEMAPINDEX_OPEN = <<~SITEMAPINDEX_OPEN
      <sitemapindex
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd"
        xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
      >
    SITEMAPINDEX_OPEN
    HEADER = "#{XML_DECLARATION}\n#{SITEMAPINDEX_OPEN}"
    FOOTER = "</sitemapindex>"

    attr_reader :sitemaps

    def initialize(xsl_url: nil)
      @sitemaps = Concurrent::Set.new
      @xsl_url = xsl_url
    end

    def add(loc, lastmod: nil)
      sitemap = loc.is_a?(Item) ? loc : Item.new(loc, lastmod)
      @sitemaps.add(sitemap)
    end

    def to_xml
      io = StringIO.new
      if @xsl_url
        io.puts(XML_DECLARATION)
        io.puts(XSLStylesheet.processing_instruction(@xsl_url))
        io.puts(SITEMAPINDEX_OPEN)
      else
        io.puts(HEADER)
      end
      @sitemaps.each do |sitemap|
        io.puts(sitemap.to_xml)
      end
      io.puts(FOOTER)
      io.string
    end

    def last_modified
      dates = @sitemaps.filter_map { |s| parse_lastmod(s.lastmod) }
      dates.max || Time.now
    end

    def empty?
      @sitemaps.empty?
    end

    private

    def parse_lastmod(value)
      case value
      when Time then value
      when String then Time.parse(value)
      end
    rescue ArgumentError
      nil
    end
  end
end
