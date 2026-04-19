# SiteMaps

A concurrent, incremental sitemap generator for Ruby. Framework-agnostic with built-in Rails support.

Generates SEO-optimized XML sitemaps with support for sitemap indexes, XSL stylesheets, gzip compression, image/video/news extensions, search engine pinging, and Rack middleware for serving sitemaps with proper HTTP headers.

## Documentation

Full guides, adapter reference, CLI docs, and recipes are published at **[gems.marcosz.com.br/site_maps](https://gems.marcosz.com.br/site_maps/)** — part of the [marcosgz Ruby gem catalogue](https://gems.marcosz.com.br).

## Table of Contents

- [Documentation](#documentation)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Processes](#processes)
- [Multi-Tenant Configuration](#multi-tenant-configuration)
- [URL Filtering](#url-filtering)
- [External Sitemaps](#external-sitemaps)
- [Sitemap Extensions](#sitemap-extensions)
- [XSL Stylesheets](#xsl-stylesheets)
- [Rack Middleware](#rack-middleware)
- [robots.txt](#robotstxt)
- [Search Engine Ping](#search-engine-ping)
- [Adapters](#adapters)
- [CLI](#cli)
- [Notifications](#notifications)
- [Mixins](#mixins)
- [Development](#development)
- [License](#license)

## Installation

Add to your Gemfile:

```ruby
gem "site_maps"
```

Then run `bundle install`.

## Quick Start

Create a configuration file:

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml"
    config.directory = Rails.public_path.to_s
  end

  process do |s|
    s.add("/", lastmod: Time.now)
    s.add("/about", lastmod: Time.now)
  end
end
```

Generate sitemaps:

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue_all
  .run
```

Or via CLI:

```bash
bundle exec site_maps generate --config-file config/sitemap.rb
```

## Configuration

Configuration can be set inside the `SiteMaps.use` block using `configure`, `config`, or by passing options directly:

```ruby
# Block style
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml.gz"
    config.directory = "/var/www/public"
  end
end

# Inline style
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemap.xml.gz"
  config.directory = "/var/www/public"
end

# Options style
SiteMaps.use(:file_system, url: "https://example.com/sitemap.xml.gz", directory: "/var/www/public")
```

### Common Options

| Option | Default | Description |
|--------|---------|-------------|
| `url` | *required* | URL of the main sitemap index file. Must end with `.xml` or `.xml.gz`. |
| `directory` | `"/tmp/sitemaps"` | Local directory for generated sitemap files. |
| `max_links` | `50_000` | Maximum URLs per sitemap file before splitting. Set to `1_000` for Yoast-style performance. |
| `emit_priority` | `true` | Include `<priority>` in XML output. Google ignores this — set to `false` to omit. |
| `emit_changefreq` | `true` | Include `<changefreq>` in XML output. Google ignores this — set to `false` to omit. |
| `xsl_stylesheet_url` | `nil` | URL of the XSL stylesheet for URL set sitemaps. Enables human-readable browser display. |
| `xsl_index_stylesheet_url` | `nil` | URL of the XSL stylesheet for the sitemap index. |
| `ping_search_engines` | `false` | Ping search engines after sitemap generation. |
| `ping_engines` | `nil` | Custom engines hash. Defaults to Bing when `nil`. |

### Gzip Compression

Append `.gz` to the sitemap URL to enable automatic gzip compression:

```ruby
config.url = "https://example.com/sitemap.xml.gz"
```

### Priority and Change Frequency

Google and most search engines ignore `<priority>` and `<changefreq>` — only `<lastmod>` is meaningful. You can disable them:

```ruby
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml"
    config.emit_priority = false
    config.emit_changefreq = false
  end
end
```

When disabled, default values (`priority: 0.5`, `changefreq: "weekly"`) are not included in the XML output. If you explicitly pass `priority:` or `changefreq:` to `s.add`, they are still emitted regardless of the flag.

## Processes

Processes define units of work for sitemap generation. Each process runs in a separate thread for concurrent generation.

### Static Processes

Execute once with a fixed location:

```ruby
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemap.xml"

  process do |s|
    s.add("/", lastmod: Time.now)
    s.add("/about", lastmod: Time.now)
  end

  process :categories, "categories/sitemap.xml" do |s|
    Category.find_each do |category|
      s.add(category_path(category), lastmod: category.updated_at)
    end
  end
end
```

### Dynamic Processes

Execute multiple times with different parameters. The location supports `%{placeholder}` interpolation:

```ruby
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemap.xml"

  process :posts, "posts/%{year}-%{month}/sitemap.xml", year: Date.today.year, month: Date.today.month do |s, year:, month:, **|
    Post.where(year: year.to_i, month: month.to_i).find_each do |post|
      s.add(post_path(post), lastmod: post.updated_at)
    end
  end
end
```

Enqueue dynamic processes with specific values:

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue(:posts, year: "2024", month: "01")
  .enqueue(:posts, year: "2024", month: "02")
  .enqueue_remaining  # enqueue all other non-enqueued processes
  .run
```

**Note:** Dynamic process arguments may be strings when coming from CLI or external sources. Add `.to_i` or other conversions in the process block as needed.

### Automatic Splitting

Sitemaps are automatically split into multiple files and a sitemap index is generated when:

- Multiple processes are defined.
- URL count exceeds `max_links` (default 50,000).
- News URL count exceeds 1,000.
- Uncompressed file size exceeds 50MB.

Split files are named sequentially: `sitemap1.xml`, `sitemap2.xml`, etc.

## Multi-Tenant Configuration

For multi-tenant applications where each site shares a config file but needs runtime context (like a `Site` model loaded from the database), use `SiteMaps.define` with the `context:` kwarg.

The `context:` value must be a `Hash`. Its keys are passed as keyword arguments to the `define` block:

```ruby
# config/sitemap.rb
SiteMaps.define do |site:, **|
  use(:file_system) do
    configure do |config|
      config.url = "https://#{site.domain}/sitemap.xml"
      config.directory = site.public_path
    end

    process do |s|
      site.pages.find_each { |p| s.add(p.path, lastmod: p.updated_at) }
    end

    process :posts, "posts/sitemap.xml" do |s|
      site.posts.published.find_each { |p| s.add(p.path, lastmod: p.updated_at) }
    end
  end
end
```

```ruby
# Usage — iterate sites, each gets its own isolated adapter
Site.find_each do |site|
  SiteMaps.generate(config_file: "config/sitemap.rb", context: {site: site}).enqueue_all.run
end
```

Multiple context values are passed as additional Hash keys:

```ruby
SiteMaps.define do |site:, locale:|
  use(:file_system) do
    config.url = "https://#{site.domain}/#{locale}/sitemap.xml"
    # ...
  end
end

SiteMaps.generate(config_file: "config/sitemap.rb", context: {site: site, locale: "en"}).run
```

### Serving with Rack Middleware

`SiteMaps::Middleware` supports multi-tenant setups via a callable `adapter:`. Because the adapter is resolved per-request, you can derive it from thread-local state set by an upstream middleware (e.g. `Current.site`):

```ruby
# Insert after your multitenancy middleware so Current.site is already set
Rails.application.middleware.insert_after MultitenancyMiddleware, SiteMaps::Middleware,
  adapter: -> {
    site = Current.site
    next unless site

    SiteMaps::Adapters::FileSystem.new(url: site.sitemap_url, directory: "tmp/")
  }
```

Both `adapter:` and the prefix options accept a 0-arg lambda (reads thread-local state) or a 1-arg lambda (receives the Rack `env`).

#### Path mapping options

Use these when the public URL path and the storage path differ:

| Option | Direction | Example |
|---|---|---|
| `public_prefix:` | Public URL has an extra prefix → strip it to find the file | Stored at `/sitemap.xml`, served at `/sitemaps/tenant/sitemap.xml` |
| `storage_prefix:` | Storage has an extra prefix → prepend it to the public path | Stored at `/sitemaps/tenant/sitemap.xml`, served at `/sitemap.xml` |

```ruby
# Sitemaps stored at /sitemaps/{slug}/sitemap.xml, served at /sitemap.xml
# (subdomain identifies the tenant, no prefix needed in the public URL)
Rails.application.middleware.insert_after MultitenancyMiddleware, SiteMaps::Middleware,
  storage_prefix: -> { site = Current.site; "/sitemaps/#{site.slug}" if site },
  adapter: -> { ... }

# Sitemaps stored at root, served at /sitemaps/{slug}/sitemap.xml
Rails.application.middleware.insert_after MultitenancyMiddleware, SiteMaps::Middleware,
  public_prefix: -> { site = Current.site; "/sitemaps/#{site.slug}" if site },
  adapter: -> { ... }
```

XSL stylesheet requests (`/_sitemap-stylesheet.xsl`, `/_sitemap-index-stylesheet.xsl`) are served directly without resolving the adapter or prefix.

### Thread safety

`SiteMaps.generate(config_file:, context:)` is thread-safe. Each call uses a thread-local scope to isolate adapter construction during `load(config_file)`, so concurrent calls from different threads don't race on module-level state:

```ruby
Site.find_each.map do |site|
  Thread.new do
    SiteMaps.generate(config_file: "config/sitemap.rb", context: {site: site}).enqueue_all.run
  end
end.each(&:join)
```

Each thread's `Runner` gets its own isolated adapter. Note that `SiteMaps.current_adapter` (the module singleton) exhibits last-writer-wins semantics under concurrency — use the `Runner`'s `#adapter` attribute if you need a specific generation's adapter.

For cases where you want to skip the config file entirely (e.g., everything dynamic from the database), instantiate adapters directly:

```ruby
adapter = SiteMaps::Adapters::FileSystem.new do
  config.url = "https://#{site.domain}/sitemap.xml"
  # ...
end
SiteMaps::Runner.new(adapter).enqueue_all.run
```

## URL Filtering

Use `url_filter` to exclude or modify URLs before they enter the sitemap. Filters receive the full URL string and the options hash. Return `false` to exclude, or a modified hash to change options:

```ruby
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemap.xml"

  # Exclude admin URLs
  url_filter { |url, _options| false if url.include?("/admin") }

  # Override priority for blog posts
  url_filter do |url, options|
    if url.include?("/blog/")
      options.merge(priority: 0.9)
    else
      options
    end
  end

  process do |s|
    s.add("/", lastmod: Time.now)
    s.add("/admin/dashboard")  # excluded by filter
    s.add("/blog/hello-world", lastmod: Time.now)  # priority overridden to 0.9
  end
end
```

Multiple filters are chained in order. If any filter returns `false`, the URL is excluded and subsequent filters are not called.

## External Sitemaps

Add third-party or externally-hosted sitemaps to your sitemap index using `external_sitemap`:

```ruby
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemap.xml"

  external_sitemap "https://cdn.example.com/products-sitemap.xml", lastmod: Time.now
  external_sitemap "https://blog.example.com/sitemap.xml"

  process do |s|
    s.add("/", lastmod: Time.now)
  end
end
```

External sitemaps appear in the sitemap index alongside your generated sitemaps. When external sitemaps are present, the index is always generated (even with a single process).

## Sitemap Extensions

### Image

Up to 1,000 images per URL. See [Google specification](https://support.google.com/webmasters/answer/178636?hl=en).

```ruby
s.add("/gallery",
  lastmod: Time.now,
  images: [
    { loc: "https://example.com/photo1.jpg", title: "Photo 1", caption: "A photo" },
    { loc: "https://example.com/photo2.jpg", title: "Photo 2" }
  ]
)
```

Attributes: `loc`, `caption`, `geo_location`, `title`, `license`.

### Video

See [Google specification](https://support.google.com/webmasters/answer/80471?hl=en).

```ruby
s.add("/videos/example",
  lastmod: Time.now,
  videos: [
    {
      thumbnail_loc: "https://example.com/thumb.jpg",
      title: "Example Video",
      description: "An example video",
      content_loc: "https://example.com/video.mp4",
      duration: 600,
      publication_date: Time.now
    }
  ]
)
```

Attributes: `thumbnail_loc`, `title`, `description`, `content_loc`, `player_loc`, `allow_embed`, `autoplay`, `duration`, `expiration_date`, `rating`, `view_count`, `publication_date`, `tags`, `tag`, `category`, `family_friendly`, `gallery_loc`, `gallery_title`, `uploader`, `uploader_info`, `price`, `live`, `requires_subscription`.

### News

Up to 1,000 news URLs per sitemap. See [Google specification](https://support.google.com/news/publisher-center/answer/9606710?hl=en).

```ruby
s.add("/article/breaking-news",
  lastmod: Time.now,
  news: {
    publication_name: "Example Times",
    publication_language: "en",
    publication_date: Time.now,
    title: "Breaking News Story",
    keywords: "breaking, news",
    genres: "PressRelease",
    access: "Subscription",
    stock_tickers: "NASDAQ:GOOG"
  }
)
```

Attributes: `publication_name`, `publication_language`, `publication_date`, `genres`, `access`, `title`, `keywords`, `stock_tickers`.

### Alternates (hreflang)

For multi-language sites. See [Google specification](https://support.google.com/webmasters/answer/189077).

```ruby
s.add("/",
  lastmod: Time.now,
  alternates: [
    { href: "https://example.com/en", lang: "en" },
    { href: "https://example.com/es", lang: "es" },
    { href: "https://example.com/fr", lang: "fr" }
  ]
)
```

Attributes: `href` (required), `lang`, `nofollow`, `media`.

### Mobile

See [Google specification](https://support.google.com/webmasters/answer/34648).

```ruby
s.add("/mobile-page", mobile: true)
```

### PageMap

For Google Custom Search. See [Google specification](https://developers.google.com/custom-search/docs/structured_data#pagemaps).

```ruby
s.add("/product",
  lastmod: Time.now,
  pagemap: {
    dataobjects: [
      {
        type: "product",
        id: "sku-123",
        attributes: [
          { name: "name", value: "Widget" },
          { name: "price", value: "19.99" }
        ]
      }
    ]
  }
)
```

## XSL Stylesheets

XSL stylesheets transform raw XML into styled HTML tables when sitemaps are opened in a browser — making them human-readable for debugging and review.

The gem ships with built-in stylesheets for both URL set sitemaps and sitemap indexes.

### Using with Rack Middleware

The simplest setup — the middleware serves both sitemaps and stylesheets:

```ruby
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml"
    config.xsl_stylesheet_url = "/_sitemap-stylesheet.xsl"
    config.xsl_index_stylesheet_url = "/_sitemap-index-stylesheet.xsl"
  end
end
```

### Using with Static Files

Generate the XSL files and serve them as static assets:

```ruby
# Write stylesheets to disk
File.write("public/sitemap-style.xsl", SiteMaps::Builder::XSLStylesheet.urlset_xsl)
File.write("public/sitemap-index-style.xsl", SiteMaps::Builder::XSLStylesheet.index_xsl)
```

Then point the config to the static URLs:

```ruby
config.xsl_stylesheet_url = "https://example.com/sitemap-style.xsl"
config.xsl_index_stylesheet_url = "https://example.com/sitemap-index-style.xsl"
```

## Rack Middleware

`SiteMaps::Middleware` serves sitemaps over HTTP with SEO-appropriate headers:

- `Content-Type: text/xml; charset=UTF-8`
- `X-Robots-Tag: noindex, follow` — prevents search engines from indexing the sitemap itself
- `Cache-Control: public, max-age=3600`

It also serves the built-in XSL stylesheets at `/_sitemap-stylesheet.xsl` and `/_sitemap-index-stylesheet.xsl`.

### Rails

```ruby
# config/application.rb
config.middleware.use SiteMaps::Middleware
```

### Rack

```ruby
# config.ru
use SiteMaps::Middleware
run MyApp
```

### Options

```ruby
use SiteMaps::Middleware,
  adapter: SiteMaps.current_adapter,        # defaults to SiteMaps.current_adapter
  public_prefix: nil,                       # strip this prefix from the public URL before lookup
  storage_prefix: nil,                      # prepend this prefix to the public URL for storage lookup
  x_robots_tag: "noindex, follow",          # default
  cache_control: "public, max-age=3600"     # default
```

Non-matching requests pass through to the next middleware.

## robots.txt

`SiteMaps::RobotsTxt` generates the `Sitemap:` directive for your `robots.txt`:

```ruby
# Get just the directive line
SiteMaps::RobotsTxt.sitemap_directive("https://example.com/sitemap.xml")
# => "Sitemap: https://example.com/sitemap.xml"

# Auto-detect from current adapter
SiteMaps::RobotsTxt.sitemap_directive
# => "Sitemap: https://example.com/sitemap.xml"

# Generate a complete robots.txt
SiteMaps::RobotsTxt.render(
  sitemap_url: "https://example.com/sitemap.xml",
  extra_directives: ["Disallow: /admin/"]
)
# => "User-agent: *\nAllow: /\nDisallow: /admin/\nSitemap: https://example.com/sitemap.xml\n"
```

In a Rails controller:

```ruby
class RobotsController < ApplicationController
  def show
    render plain: SiteMaps::RobotsTxt.render
  end
end
```

## Search Engine Ping

After sitemap generation, ping search engines to notify them of updates:

```ruby
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml"
    config.ping_search_engines = true
  end
end
```

By default, only Bing is pinged (`https://www.bing.com/ping?sitemap=...`). Google deprecated their ping endpoint in 2023 — they discover sitemaps via `robots.txt` and Search Console.

### Custom Engines

```ruby
config.ping_engines = {
  bing: "https://www.bing.com/ping?sitemap=%{url}",
  google: "https://www.google.com/ping?sitemap=%{url}",
  custom: "https://search.example.com/ping?url=%{url}"
}
```

### Ping via generate / CLI

Use the `ping:` option to trigger a ping for a specific run without changing the config file:

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb", ping: true).enqueue_all.run
```

```bash
bundle exec site_maps generate --config-file config/sitemap.rb --ping
```

`ping: true` overrides `config.ping_search_engines`. `ping: false` suppresses pinging even if the config enables it. Omitting `ping:` (the default) defers to the config value.

### Manual Ping

```ruby
SiteMaps::Ping.ping("https://example.com/sitemap.xml")
# => { bing: { status: 200, url: "https://www.bing.com/ping?sitemap=..." } }
```

## Adapters

### File System

Writes sitemaps to the local filesystem:

```ruby
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemap.xml.gz"
    config.directory = "/var/www/public"
  end
end
```

### AWS S3

Writes sitemaps to an S3 bucket:

```ruby
SiteMaps.use(:aws_sdk) do
  configure do |config|
    config.url = "https://my-bucket.s3.amazonaws.com/sitemaps/sitemap.xml"
    config.directory = "/tmp"
    config.bucket = "my-bucket"
    config.region = "us-east-1"
    config.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
    config.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
    config.acl = "public-read"                          # default
    config.cache_control = "private, max-age=0, no-cache" # default
  end
end
```

### Custom Adapters

Implement the `SiteMaps::Adapters::Adapter` interface:

```ruby
class MyAdapter < SiteMaps::Adapters::Adapter
  def write(url, raw_data, **kwargs)
    # Write sitemap data to storage
  end

  def read(url)
    # Return [raw_data, { content_type: "application/xml" }]
  end

  def delete(url)
    # Delete sitemap from storage
  end
end

SiteMaps.use(MyAdapter) do
  config.url = "https://example.com/sitemap.xml"
end
```

For adapter-specific configuration, define a nested `Config` class:

```ruby
class MyAdapter < SiteMaps::Adapters::Adapter
  class Config < SiteMaps::Configuration
    attribute :api_key, default: -> { ENV["MY_API_KEY"] }
  end
end
```

## CLI

```bash
# Generate all sitemaps
bundle exec site_maps generate --config-file config/sitemap.rb

# Enqueue a dynamic process with context
bundle exec site_maps generate monthly_posts \
  --config-file config/sitemap.rb \
  --context=year:2024 month:1

# Enqueue dynamic + remaining processes
bundle exec site_maps generate monthly_posts \
  --config-file config/sitemap.rb \
  --context=year:2024 month:1 \
  --enqueue-remaining

# Control concurrency
bundle exec site_maps generate \
  --config-file config/sitemap.rb \
  --max-threads 10
```

## Notifications

Subscribe to internal events for monitoring sitemap generation:

| Event | Description |
|-------|-------------|
| `sitemaps.enqueue_process` | A process was enqueued |
| `sitemaps.before_process_execution` | A process is about to start |
| `sitemaps.process_execution` | A process finished execution |
| `sitemaps.finalize_urlset` | A URL set was finalized and written |
| `sitemaps.ping` | Search engines were pinged |

```ruby
SiteMaps::Notification.subscribe("sitemaps.finalize_urlset") do |event|
  puts "Wrote #{event.payload[:links_count]} links to #{event.payload[:url]}"
end
```

Use the built-in event listener for console output:

```ruby
SiteMaps::Notification.subscribe(SiteMaps::Runner::EventListener)
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue_all
  .run
```

## Mixins

Extend the sitemap builder with custom methods shared across processes:

```ruby
module SitemapHelpers
  def repository
    Repository.new
  end
end

SiteMaps.use(:file_system) do
  extend_processes_with(SitemapHelpers)

  process do |s|
    s.repository.posts.each do |post|
      s.add("/posts/#{post.slug}", lastmod: post.updated_at)
    end
  end
end
```

Rails applications get a built-in mixin with URL helpers via the `route` method:

```ruby
process do |s|
  s.add(s.route.root_path, lastmod: Time.now)
  s.add(s.route.about_path, lastmod: Time.now)
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Run `bin/console` for an interactive prompt.

```bash
bundle exec rspec        # run tests
bundle exec rubocop      # run linter
bundle exec rake install # install locally
```

Bug reports and pull requests are welcome on [GitHub](https://github.com/marcosgz/site_maps).

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
