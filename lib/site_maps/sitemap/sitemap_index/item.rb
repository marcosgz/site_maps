# frozen_string_literal: true

class SiteMaps::Sitemap::SitemapIndex::Item < Struct.new(:loc, :lastmod)
  extend Forwardable

  def to_xml
    builder = ::Builder::XmlMarkup.new
    builder.sitemap do
      builder.loc(loc)
      builder.lastmod w3c_date(lastmod) if lastmod
    end
    builder << "\n"
  end

  def eql?(other)
    loc == other.loc
  end
  alias_method :==, :eql?

  protected

  def_delegator SiteMaps::Sitemap::Normalizer, :w3c_date
end
