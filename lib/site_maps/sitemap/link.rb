# frozen_string_literal: true

module SiteMaps::Sitemap
  class Link
    attr_reader :uri

    def initialize(base_url, path, params = {})
      @uri = ::URI.parse(base_url)
      @uri.user, @uri.query = nil
      @uri.path = path
      @uri.query = Rack::Utils.unescape(Rack::Utils.build_nested_query(params)) if params.is_a?(Hash) && params.any?
    end

    def to_s
      @uri.to_s
    end

    def eql?(other)
      to_s == other.to_s
    end
    alias_method :==, :eql?
  end
end
