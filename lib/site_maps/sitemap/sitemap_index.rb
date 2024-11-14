# frozen_string_literal: true

module SiteMaps::Sitemap
  class SitemapIndex
    HEADER = <<~HEADER
      <?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd"
        xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
      >
    HEADER
    FOOTER = "</sitemapindex>"

    attr_reader :sitemaps

    def initialize
      @sitemaps = Concurrent::Set.new
    end

    def add(loc, lastmod: nil)
      sitemap = Item.new(loc, lastmod)
      @sitemaps.add(sitemap)
    end

    def to_xml
      io = StringIO.new
      io.puts(HEADER)
      @sitemaps.each do |sitemap|
        io.puts(sitemap.to_xml)
      end
      io.puts(FOOTER)
      io.string
    end

    def empty?
      @sitemaps.empty?
    end
  end
end
