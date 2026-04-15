# frozen_string_literal: true

module SiteMaps
  class Middleware
    DEFAULT_X_ROBOTS_TAG = "noindex, follow"
    DEFAULT_CACHE_CONTROL = "public, max-age=3600"
    URLSET_XSL_PATH = "/_sitemap-stylesheet.xsl"
    INDEX_XSL_PATH = "/_sitemap-index-stylesheet.xsl"

    # Matches sitemap filenames with page 0 or 1 suffix for redirect normalization
    # e.g., "sitemap0.xml" → "sitemap.xml", "posts1.xml.gz" → "posts.xml.gz"
    PAGE_NORMALIZE_RE = /\A(.+?)(?:0|1)(\.(xml|xml\.gz))\z/

    # @param adapter [Object, #call, nil] Adapter instance, a callable that receives
    #   the Rack env and returns an adapter (for multi-tenant use), or nil to use
    #   SiteMaps.current_adapter.
    # @param path_prefix [String, #call, nil] A path prefix to strip from incoming
    #   requests before matching sitemap paths. Useful for multi-tenant setups where
    #   sitemaps are served under a tenant-specific path (e.g. "/sitemaps/tenant-slug").
    #   Can be a callable that receives the Rack env and returns a string or nil.
    def initialize(app, adapter: nil, path_prefix: nil, x_robots_tag: DEFAULT_X_ROBOTS_TAG, cache_control: DEFAULT_CACHE_CONTROL)
      @app = app
      @adapter = adapter
      @path_prefix = path_prefix
      @x_robots_tag = x_robots_tag
      @cache_control = cache_control
    end

    def call(env)
      path = env["PATH_INFO"]

      if xsl_request?(path)
        serve_xsl(path)
      else
        current_adapter = resolve_adapter(env)
        prefix = resolve_prefix(env)
        internal_path = strip_prefix(path, prefix)

        if internal_path && current_adapter && (redirect = normalize_path(internal_path, current_adapter))
          redirect_to("#{prefix}#{redirect}")
        elsif internal_path && current_adapter && sitemap_request?(internal_path, current_adapter)
          serve_sitemap(internal_path, current_adapter)
        else
          @app.call(env)
        end
      end
    end

    private

    def resolve_adapter(env)
      if @adapter.respond_to?(:call)
        call_with_env(@adapter, env)
      else
        @adapter || SiteMaps.current_adapter
      end
    end

    def resolve_prefix(env)
      prefix = @path_prefix.respond_to?(:call) ? call_with_env(@path_prefix, env) : @path_prefix
      prefix&.chomp("/")
    end

    # Calls a callable with env if it accepts an argument, otherwise calls it
    # with no arguments. This allows both `-> { Current.site }` (0-arg, useful
    # when upstream middleware already set thread-local state) and
    # `->(env) { ... }` (1-arg) forms.
    def call_with_env(callable, env)
      callable.arity.zero? ? callable.call : callable.call(env)
    end

    # Returns the path with the prefix stripped, nil if the prefix is set but
    # doesn't match, or the original path when no prefix is configured.
    def strip_prefix(path, prefix)
      return path if prefix.nil? || prefix.empty?
      return nil unless path.start_with?(prefix)

      stripped = path[prefix.length..]
      stripped.start_with?("/") ? stripped : "/#{stripped}"
    end

    def sitemap_request?(path, adapter)
      sitemap_dir = adapter.config.remote_sitemap_directory
      prefix = sitemap_dir.empty? ? "/" : "/#{sitemap_dir}/"
      path.start_with?(prefix) && path.end_with?(".xml", ".xml.gz")
    end

    def xsl_request?(path)
      path == URLSET_XSL_PATH || path == INDEX_XSL_PATH
    end

    # Returns the normalized path if a redirect is needed, nil otherwise.
    # Normalizes page 0 and page 1 to the base sitemap URL (Yoast-style).
    def normalize_path(path, adapter)
      return unless sitemap_request?(path, adapter)

      basename = File.basename(path)
      match = PAGE_NORMALIZE_RE.match(basename)
      return unless match

      dir = File.dirname(path)
      normalized = if dir == "/"
        "/#{match[1]}#{match[2]}"
      else
        "#{dir}/#{match[1]}#{match[2]}"
      end
      normalized unless normalized == path
    end

    def redirect_to(path)
      [301, {"location" => path, "content-type" => "text/html"}, ["Moved Permanently"]]
    end

    def serve_sitemap(path, adapter)
      url = "#{adapter.config.base_uri}#{path}"
      raw_data, metadata = adapter.read(url)
      body = decompress(raw_data, metadata)

      [200, sitemap_headers("text/xml; charset=UTF-8"), [body]]
    rescue SiteMaps::FileNotFoundError
      @app.call({"PATH_INFO" => path, "REQUEST_METHOD" => "GET"})
    end

    # The adapter may return gzip-compressed data (raw bytes) or already-decompressed
    # XML. Always serve as plain XML so sitemaps are browsable with XSL stylesheets.
    def decompress(raw_data, metadata)
      return raw_data unless metadata && metadata[:content_type] == "application/gzip"

      Zlib::GzipReader.new(StringIO.new(raw_data)).read
    rescue Zlib::GzipFile::Error
      # Data was already decompressed (e.g., FileSystem adapter decompresses on read)
      raw_data
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
