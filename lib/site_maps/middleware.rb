# frozen_string_literal: true

module SiteMaps
  class Middleware
    DEFAULT_X_ROBOTS_TAG = "noindex, follow"
    DEFAULT_CACHE_CONTROL = "public, max-age=3600"
    URLSET_XSL_PATH = "/_sitemap-stylesheet.xsl"
    INDEX_XSL_PATH = "/_sitemap-index-stylesheet.xsl"

    def initialize(app, adapter: nil, x_robots_tag: DEFAULT_X_ROBOTS_TAG, cache_control: DEFAULT_CACHE_CONTROL)
      @app = app
      @adapter = adapter
      @x_robots_tag = x_robots_tag
      @cache_control = cache_control
    end

    def call(env)
      path = env["PATH_INFO"]

      if xsl_request?(path)
        serve_xsl(path)
      elsif sitemap_request?(path)
        serve_sitemap(path)
      else
        @app.call(env)
      end
    end

    private

    def adapter
      @adapter || SiteMaps.current_adapter
    end

    def sitemap_request?(path)
      sitemap_dir = adapter.config.remote_sitemap_directory
      prefix = sitemap_dir.empty? ? "/" : "/#{sitemap_dir}/"
      path.start_with?(prefix) && path.end_with?(".xml", ".xml.gz")
    end

    def xsl_request?(path)
      path == URLSET_XSL_PATH || path == INDEX_XSL_PATH
    end

    def serve_sitemap(path)
      url = "#{adapter.config.base_uri}#{path}"
      raw_data, metadata = adapter.read(url)
      content_type = metadata[:content_type] || "text/xml; charset=UTF-8"
      content_type = "text/xml; charset=UTF-8" if content_type == "application/xml"

      [200, sitemap_headers(content_type), [raw_data]]
    rescue SiteMaps::FileNotFoundError
      @app.call({"PATH_INFO" => path, "REQUEST_METHOD" => "GET"})
    end

    def serve_xsl(path)
      body = if path == INDEX_XSL_PATH
        Builder::XSLStylesheet.index_xsl
      else
        Builder::XSLStylesheet.urlset_xsl
      end

      [200, xsl_headers, [body]]
    end

    def sitemap_headers(content_type)
      {
        "content-type" => content_type,
        "x-robots-tag" => @x_robots_tag,
        "cache-control" => @cache_control
      }
    end

    def xsl_headers
      {
        "content-type" => "text/xsl; charset=UTF-8",
        "cache-control" => @cache_control
      }
    end
  end
end
