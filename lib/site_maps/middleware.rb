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

    # @param adapter [Object, #call, nil] Adapter instance, a callable (0-arg or 1-arg
    #   receiving the Rack env) that returns an adapter, or nil to fall back to
    #   SiteMaps.current_adapter.
    #
    # @param public_prefix [String, #call, nil] A prefix present in the **public URL**
    #   that is absent from the storage path. Stripped from the incoming request path
    #   to derive the internal lookup path.
    #
    #   Example: sitemaps stored at `/sitemap.xml`, served publicly at
    #   `/sitemaps/tenant/sitemap.xml` → `public_prefix: "/sitemaps/tenant"`
    #
    # @param storage_prefix [String, #call, nil] A prefix present in the **storage
    #   path** that is absent from the public URL. Prepended to the incoming request
    #   path to derive the internal lookup path.
    #
    #   Example: sitemaps stored at `/sitemaps/tenant/sitemap.xml`, served publicly at
    #   `/sitemap.xml` → `storage_prefix: "/sitemaps/tenant"`
    #
    # Both options accept a callable (0-arg or 1-arg receiving env), which is useful
    # in multi-tenant setups where the prefix depends on the current request/site.
    #
    def initialize(
      app,
      adapter: nil,
      public_prefix: nil,
      storage_prefix: nil,
      x_robots_tag: DEFAULT_X_ROBOTS_TAG,
      cache_control: DEFAULT_CACHE_CONTROL
    )
      @app = app
      @adapter = adapter
      @public_prefix = public_prefix
      @storage_prefix = storage_prefix
      @x_robots_tag = x_robots_tag
      @cache_control = cache_control
    end

    def call(env)
      path = env["PATH_INFO"]

      if xsl_request?(path)
        serve_xsl(path)
      else
        current_adapter = resolve_adapter(env)
        pub_prefix = resolve_value(@public_prefix, env)
        sto_prefix = resolve_value(@storage_prefix, env)

        # Strip public prefix (nil = no match when prefix is configured but doesn't match)
        stripped = strip_prefix(path, pub_prefix)

        # Prepend storage prefix to get the internal path used for adapter lookups
        internal_path = stripped && prepend_prefix(stripped, sto_prefix)

        if internal_path && current_adapter && (redirect = normalize_path(internal_path, current_adapter))
          # Convert internal redirect back to public path
          public_redirect = "#{pub_prefix}#{strip_prefix(redirect, sto_prefix)}"
          redirect_to(public_redirect)
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

    # Resolves a string-or-callable option, normalising the trailing slash.
    def resolve_value(option, env)
      value = option.respond_to?(:call) ? call_with_env(option, env) : option
      value&.chomp("/")
    end

    # Calls a callable with env if it accepts an argument, otherwise with no
    # arguments. Supports both `-> { Current.site }` (0-arg, when upstream
    # middleware already set thread-local state) and `->(env) { ... }` (1-arg).
    def call_with_env(callable, env)
      callable.arity.zero? ? callable.call : callable.call(env)
    end

    # Returns the path with the prefix stripped.
    # Returns nil  when a prefix is configured but the path doesn't start with it
    # (so the middleware can pass through non-matching requests).
    # Returns the original path when no prefix is configured.
    def strip_prefix(path, prefix)
      return path if prefix.nil? || prefix.empty?
      return nil unless path.start_with?(prefix)

      stripped = path[prefix.length..]
      stripped.start_with?("/") ? stripped : "/#{stripped}"
    end

    # Prepends a storage prefix to a path. A nil/empty prefix is a no-op.
    def prepend_prefix(path, prefix)
      return path if prefix.nil? || prefix.empty?

      "#{prefix}#{path}"
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
