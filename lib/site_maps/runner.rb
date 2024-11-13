# frozen_string_literal: true

module SiteMaps
  class Runner
    attr_reader :adapter

    def initialize(adapter = SiteMaps.current_adapter, max_threads: 4)
      @adapter = adapter
      @pool = Concurrent::FixedThreadPool.new(max_threads)
      @execution = Concurrent::Hash.new
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
            process.call(nil, **kwargs)
          end
        end
      end

      pool.shutdown
      pool.wait_for_termination
      @execution.clear
    end

    private

    attr_reader :pool
  end
end
