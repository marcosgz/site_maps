# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle exec rspec                   # Run all tests
bundle exec rspec spec/path/to_spec.rb  # Run a single spec file
bundle exec rspec spec/path/to_spec.rb:42  # Run a single example by line
bundle exec rubocop                 # Run linter
bundle exec rubocop -a              # Auto-correct offenses
bundle exec rake install            # Install gem locally
```

## Architecture

`SiteMaps` is a concurrent, incremental sitemap.xml generator gem. It is framework-agnostic but ships with a Rails Railtie.

### Adapter Pattern

Storage backends (`FileSystem`, `AwsSdk`, `Noop`) all inherit from `Adapters::Adapter`. Each adapter can ship its own `Config` class (inheriting `SiteMaps::Configuration`) and optional process mixins. The active adapter is stored in `SiteMaps.current_adapter` and set via `SiteMaps.use(:adapter_name, **opts)`.

### Process Model

Work is declared as named **processes**. A process can be **static** (executed once, fixed location) or **dynamic** (executed multiple times with a location template like `posts/%{year}-%{month}/sitemap.xml`). Processes are stored as immutable structs with block callbacks and orchestrated by `Runner`.

### Runner and Concurrency

`Runner` manages a `concurrent-ruby` `FixedThreadPool` (default 4 threads). Processes are enqueued with `enqueue(:name, **args)`, `enqueue_remaining`, or `enqueue_all`, then executed by calling `run`. `AtomicRepository` provides thread-safe tracking of processes and URL sets. `SitemapBuilder` uses a `Mutex` for synchronization.

### XML Generation

`Builder::URLSet` writes a single sitemap XML file (max 50,000 links or ~50MB). When a limit is reached, `IncrementalLocation` generates the next filename automatically. `Builder::SitemapIndex` aggregates multiple URLSets. `Builder::URL` handles sitemap extensions: images, videos, news, alternates, mobile, and pagemap.

### Notification System

`Notification::Publisher` is a mixin that enables event-driven hooks. Key events: `sitemaps.enqueue_process`, `sitemaps.before_process_execution`, `sitemaps.process_execution`, `sitemaps.finalize_urlset`. Subscribe via `SiteMaps.subscribe(event) { |payload| ... }`.

### Configuration

`Configuration` uses an `attribute` macro for declaring settings with defaults. Adapter-specific configs inherit from the base class. Config is set with `SiteMaps.configure { |c| ... }` or inline inside `SiteMaps.use`.

### CLI

Implemented with Thor in `lib/site_maps/cli.rb`, exposed via the `exec/site_maps` binary. The main command is `site_maps generate [processes]` with flags `--config-file`, `--max-threads`, `--context` (key:value pairs for dynamic processes), `--enqueue-remaining`, `--ping`, `--debug`, and `--logfile`.

### Rails Integration

`lib/site_maps/railtie.rb` is auto-loaded when Rails is present. It injects Rails URL helpers into process blocks via a `route` helper method.

## Development Guidelines

- **Any new public-facing feature** (new option, method, CLI flag, or behaviour change) must be documented in `README.md` before the work is considered complete. This includes: new `generate`/`Runner` options, new middleware options, new CLI flags, new config attributes, and new DSL methods.

## Typical Usage Pattern

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz"
    config.directory = Rails.public_path.to_s
  end

  process do |s|                          # static, default process
    s.add("/", priority: 1.0)
  end

  process :posts, "posts/%{year}-%{month}/sitemap.xml", year: 2024, month: 1 do |s, year:, month:|
    Post.where(year: year, month: month).find_each { |p| s.add(post_path(p)) }
  end
end

# Generate
SiteMaps.generate(config_file: "config/sitemap.rb").enqueue_all.run
```
