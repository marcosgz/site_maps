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
      @execution.each do |_process_name, items|
        items.each do |process, kwargs|
          Concurrent::Future.execute(executor: pool) do
            next if failed.true?

            begin
              builder = SiteMaps::SitemapBuilder.new(
                adapter: adapter,
                location: process.location
              )
              process.call(builder, **kwargs)
              builder.finalize!
            rescue => e
              handle_process_error(process, e)
              failed.make_true
            end
          end
        end
      end

      pool.shutdown
      pool.wait_for_termination
      @execution.clear

      failed.false? ? finalize! : fail_with_errors!
    end

    private

    attr_reader :pool, :failed

    def finalize!
      unless adapter.sitemap_index.empty?
        raw_data = adapter.sitemap_index.to_xml
        adapter.write(adapter.config.url, raw_data)
      end
    end

    def fail_with_errors!
      # @TODO raise
    end

    def handle_process_error(process, error)
      @errors << [process, error]
    end
  end
end
