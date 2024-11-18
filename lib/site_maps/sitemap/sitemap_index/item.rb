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

  def hash
    loc.hash
  end

  def relative_directory
    return unless loc =~ %r{^https?://[^/]+(/.*)$}

    val = File.dirname(Regexp.last_match(1))
    val = val[1..-1] if val.start_with?("/")
    val
  end

  protected

  def_delegator SiteMaps::Sitemap::Normalizer, :w3c_date
end
