# frozen_string_literal: true

module SiteMaps
  class Runner
    attr_reader :adapter

    def initialize(adapter = SiteMaps.current_adapter, max_threads: 4)
      @adapter = adapter.tap(&:reset!)
      @pool = Concurrent::FixedThreadPool.new(max_threads)
      @execution = Concurrent::Hash.new
      @failed = Concurrent::AtomicBoolean.new(false)
      @errors = Concurrent::Array.new
    end

    def enqueue(process_name = :default, **kwargs)
      process_name = process_name.to_sym
      process = @adapter.processes.fetch(process_name) do
        raise ArgumentError, "Process :#{process_name} not found"
      end
      kwargs = process.keyword_arguments(kwargs)
      SiteMaps::Notification.instrument("sitemaps.runner.enqueue_process") do |payload|
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
          SiteMaps::Notification.publish("sitemaps.runner.before_process_execution", process: process, kwargs: kwargs)
          futures << Concurrent::Future.execute(executor: pool) do
            wrap_process_execution(process) do
              SiteMaps::Notification.instrument("sitemaps.runner.process_execution") do |payload|
                payload[:process] = process
                payload[:kwargs] = kwargs
                builder = SiteMaps::SitemapBuilder.new(
                  adapter: adapter,
                  location: process.location(**kwargs)
                )
                process.call(builder, **kwargs)
                builder.finalize!
              end
            end
          end
        end
      end

      futures.each(&:wait)
      failed.false? ? finalize! : fail_with_errors!
    ensure
      pool.shutdown
      pool.wait_for_termination
      @execution.clear
    end

    private

    attr_reader :pool, :failed, :errors

    def finalize!
      adapter.repo.remaining_index_links.each do |item|
        adapter.sitemap_index.add(item)
      end
      unless adapter.sitemap_index.empty?
        raw_data = adapter.sitemap_index.to_xml
        adapter.write(adapter.config.url, raw_data, last_modified: Time.now)
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
      return unless preload_sitemap_index_links?

      adapter.fetch_sitemap_index_links.each do |item|
        adapter.repo.preloaded_index_links.push(item)
      end
    end

    def wrap_process_execution(process)
      return if failed.true?

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
