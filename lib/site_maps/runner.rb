# frozen_string_literal: true

module SiteMaps
  class Runner
    attr_reader :adapter

    def initialize(adapter = SiteMaps.current_adapter, max_threads: 4)
      @adapter = adapter
      @pool = Concurrent::FixedThreadPool.new(max_threads)
      @execution = Concurrent::Hash.new
      @failed = Concurrent::AtomicBoolean.new(false)
      @errors = Concurrent::Array.new
    end

    def enqueue(process_name = :default, **kwargs)
      process_name = process_name.to_sym
      process = @adapter.processes.fetch(process_name)
      if process.dynamic?
        @execution[process_name] ||= Concurrent::Array.new
        @execution[process_name] << [process, kwargs]
      else
        if @execution.key?(process_name)
          raise ArgumentError, "Process #{process_name} already defined"
        end
        @execution[process_name] = Concurrent::Array.new([[process, kwargs]])
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

      if false && single_thread?
        _process_name, items = @execution.first
        process, kwargs = items.first
        builder = SiteMaps::SitemapBuilder.new(
          adapter: adapter,
          location: process.location
        )
        process.call(builder, **kwargs)
        builder.finalize!
        finalize!
      else
        @execution.each do |_process_name, items|
          items.each do |process, kwargs|
            Concurrent::Future.execute(executor: pool) do
              wrap_process_execution(process) do
                builder = SiteMaps::SitemapBuilder.new(
                  adapter: adapter,
                  location: process.location
                )
                process.call(builder, **kwargs)
                builder.finalize!
              end
            end
          end
        end

        pool.shutdown
        pool.wait_for_termination
        @execution.clear

        failed.false? ? finalize! : fail_with_errors!
      end
    end

    private

    attr_reader :pool, :failed, :errors

    def finalize!
      unless adapter.sitemap_index.empty?
        raw_data = adapter.sitemap_index.to_xml
        adapter.write(adapter.config.url, raw_data, last_modified: Time.now)
      end
    end

    def fail_with_errors!
      return if errors.empty?

      raise SiteMaps::RunnerError.new(errors)
    end

    def handle_process_error(process, error)
      errors << [process, error]
    end

    def may_preload_sitemap_index
      return unless preload_sitemap_index_links?

      # @todo: Implement preload_sitemap_index
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
        @execution.any? { |_, items| items.any? { |process, _| process.dynamic? } } # There are dynamic processes
    end

    def single_thread?
      @pool.max_length == 1 || (
        @execution.size == 1 && @execution.first.last.size == 1
      )
    end
  end
end
