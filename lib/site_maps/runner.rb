# frozen_string_literal: true

module SiteMaps
  class Runner
    attr_reader :adapter

    def initialize(adapter = SiteMaps.current_adapter, max_threads: 4, ping: nil)
      @adapter = adapter.tap(&:reset!)
      @ping = ping
      @pool = Concurrent::FixedThreadPool.new(max_threads)
      @execution = Concurrent::Hash.new
      @failed = Concurrent::AtomicBoolean.new(false)
      @errors = Concurrent::Array.new
      @written = Concurrent::Array.new
    end

    def enqueue(process_name = :default, **kwargs)
      process_name = process_name.to_sym
      process = @adapter.processes.fetch(process_name) do
        raise ArgumentError, "Process :#{process_name} not found"
      end
      kwargs = process.keyword_arguments(kwargs)
      SiteMaps::Notification.instrument("sitemaps.enqueue_process") do |payload|
        payload[:process] = process
        payload[:kwargs] = kwargs
        if process.dynamic?
          @execution[process_name] ||= Concurrent::Array.new
          if @execution[process_name].any? { |_, k| k == kwargs }
            raise ArgumentError, "Process :#{process_name} already enqueued with kwargs #{kwargs}"
          end
          @execution[process_name] << [process, kwargs]
        else
          if @execution.key?(process_name)
            raise ArgumentError, "Process :#{process_name} already defined"
          end
          @execution[process_name] = Concurrent::Array.new([[process, kwargs]])
        end
      end
      self
    end

    def enqueue_remaining
      @adapter.processes.each_key do |process_name|
        next if @execution.key?(process_name)

        enqueue(process_name)
      end
      self
    end
    alias_method :enqueue_all, :enqueue_remaining

    def run
      may_preload_sitemap_index

      futures = []
      @execution.each do |_process_name, items|
        items.each do |process, kwargs|
          SiteMaps::Notification.publish("sitemaps.before_process_execution", process: process, kwargs: kwargs)
          futures << Concurrent::Future.execute(executor: pool) do
            wrap_process_execution(process) do
              SiteMaps::Notification.instrument("sitemaps.process_execution") do |payload|
                payload[:process] = process
                payload[:kwargs] = kwargs
                builder = SiteMaps::SitemapBuilder.new(
                  adapter: adapter,
                  location: process.location(**kwargs),
                  notification_payload: {process: process}
                )
                adapter.process_mixins.each { |mixin| builder.extend(mixin) }
                process.call(builder, **kwargs)
                builder.finalize!
                written << [process.location(**kwargs), builder.written_urls]
              end
            end
          end
        end
      end

      futures.each(&:wait)
      if failed.false?
        finalize!
      else
        write_index! if index_from_storage?
        fail_with_errors!
      end
    ensure
      pool.shutdown
      pool.wait_for_termination
      @execution.clear
      @written.clear
    end

    # Rewrites the sitemap index from the sitemap files found in storage,
    # without running any process.
    def rebuild_index!
      add_stored_index_links(adapter.list_sitemaps)
      add_external_index_links
      write_sitemap_index
      self
    end

    private

    attr_reader :pool, :failed, :errors, :written

    def finalize!
      write_index!
      should_ping = @ping.nil? ? adapter.config.respond_to?(:ping_search_engines?) && adapter.config.ping_search_engines? : @ping
      ping_search_engines if should_ping
    end

    def write_index!
      if index_from_storage?
        add_stored_index_links(prune_stale_sitemaps(adapter.list_sitemaps))
      else
        adapter.repo.remaining_index_links.each do |item|
          adapter.sitemap_index.add(item)
        end
      end
      add_external_index_links
      write_sitemap_index
    end

    def write_sitemap_index
      return if adapter.sitemap_index.empty?

      raw_data = adapter.sitemap_index.to_xml
      adapter.write(adapter.config.url, raw_data, last_modified: adapter.sitemap_index.last_modified)
    end

    def add_external_index_links
      adapter.external_sitemaps.each do |item|
        adapter.sitemap_index.add(item)
      end
    end

    # Adds the stored files that belong to a declared process. Files written by
    # this run are already in the index, and the index keeps the first entry
    # added for each location.
    def add_stored_index_links(stored)
      patterns = adapter.processes.values.map do |process|
        SiteMaps::IncrementalLocation.template_pattern(adapter.config.url, process.location_template)
      end

      stored.each do |item|
        next if item.loc == adapter.config.url
        next unless patterns.any? { |pattern| pattern.match?(item.loc) }

        adapter.sitemap_index.add(item)
      end
    end

    # Deletes the numbered parts a successful process no longer writes, such as
    # sitemap3.xml after a month shrank to two files. Returns the stored files
    # that are left.
    def prune_stale_sitemaps(stored)
      stale = written.flat_map do |location, urls|
        next [] if urls.empty?

        pattern = SiteMaps::IncrementalLocation.new(adapter.config.url, location).pattern
        stored.select { |item| pattern.match?(item.loc) && !urls.include?(item.loc) && item.loc != adapter.config.url }
      end

      stale.each do |item|
        SiteMaps::Notification.instrument("sitemaps.prune_sitemap") do |payload|
          payload[:url] = item.loc
          adapter.delete(item.loc)
        rescue SiteMaps::FileNotFoundError
          nil
        end
      end

      stored - stale
    end

    def index_from_storage?
      adapter.config.respond_to?(:index_from_storage?) && adapter.config.index_from_storage?
    end

    def ping_search_engines
      engines = adapter.config.respond_to?(:ping_engines) ? adapter.config.ping_engines : nil
      SiteMaps::Notification.instrument("sitemaps.ping") do |payload|
        payload[:results] = SiteMaps::Ping.ping(adapter.config.url, engines: engines)
      end
    end

    def fail_with_errors!
      return if errors.empty?

      raise errors.first.last
    end

    def handle_process_error(process, error)
      errors << [process, error]
    end

    def may_preload_sitemap_index
      return if index_from_storage?
      return unless preload_sitemap_index_links?

      adapter.fetch_sitemap_index_links.each do |item|
        adapter.repo.preloaded_index_links.push(item)
      end
    end

    # A failure stops the remaining processes, unless the index is rebuilt from
    # storage: then every independent process still gets its chance to publish.
    def wrap_process_execution(process)
      return if failed.true? && !index_from_storage?

      yield
    rescue => e
      handle_process_error(process, e)
      failed.make_true
    end

    def preload_sitemap_index_links?
      return false if @execution.empty?

      (@adapter.processes.keys - @execution.keys).any? || # There are processes that have not been enqueued
        @adapter.processes.any? { |_, process| process.dynamic? } # There are dynamic processes
    end

    # def single_thread?
    #   @pool.max_length == 1 || (
    #     @execution.size == 1 && @execution.first.last.size == 1
    #   )
    # end
  end
end
