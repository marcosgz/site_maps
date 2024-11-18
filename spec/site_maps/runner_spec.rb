# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Runner do
  let(:adapter) do
    SiteMaps.use(:noop) do
      configure do |config|
        config.url = "https://example.com/site/sitemap.xml"
      end

      process do |s|
        s.add("/index.html")
        s.add("/about.html")
        s.add("/contact.html")
      end

      categories = %w[news sports entertainment]

      process(:categories) do |s|
        categories.each do |category|
          s.add("/#{category}.html")
        end
      end

      process(:posts, "posts/%{year}-%{month}/sitemap.xml", year: 2024, month: nil) do |s, year:, month:|
        s.add("/posts/#{year}/#{month}/index.html")
      end
    end
  end
  let(:runner) { described_class.new(adapter, max_threads: 2) }

  describe "#initialize" do
    it "sets the adapter and config" do
      expect(runner.adapter).to eq(adapter)
    end

    it "initializes the pool" do
      expect(runner.instance_variable_get(:@pool)).to be_a(Concurrent::FixedThreadPool)
    end

    it "initializes the execution" do
      expect(runner.instance_variable_get(:@execution)).to be_a(Concurrent::Hash)
    end

    it "resets the adapter running state" do
      adapter.sitemap_index.add("https://example.com/site/sitemap1.xml")
      adapter.repo.generate_url("https://example.com/site/group/sitemap1.xml")

      runner = described_class.new(adapter, max_threads: 2)
      expect(adapter.sitemap_index).to be_empty
      expect(adapter.instance_variable_get(:@repo)).to be_nil
      expect(adapter.repo.preloaded_index_links).to be_empty
    end
  end

  describe "#enqueue" do
    it "adds the default process when no process name is provided" do
      result = runner.enqueue

      expect(result).to eq(runner)
      expect(queue = runner.instance_variable_get(:@execution)).to have_key(:default)
      expect(queue[:default]).to containing_exactly([
        an_instance_of(SiteMaps::Process),
        {}
      ])
    end

    it "adds the process to the execution" do
      result = runner.enqueue(:categories)

      expect(result).to eq(runner)
      expect(queue = runner.instance_variable_get(:@execution)).to have_key(:categories)
      expect(queue[:categories]).to containing_exactly([
        an_instance_of(SiteMaps::Process),
        {}
      ])
    end

    it "does not add the process to the execution if static process is already defined" do
      runner.enqueue(:categories)

      expect {
        runner.enqueue(:categories)
      }.to raise_error(ArgumentError)
    end

    it "adds the dynamic process to the execution with the provided arguments" do
      result = runner.enqueue(:posts, year: 2020, month: 1)

      expect(result).to eq(runner)
      expect(queue = runner.instance_variable_get(:@execution)).to have_key(:posts)
      expect(queue[:posts]).to containing_exactly([
        an_instance_of(SiteMaps::Process),
        {year: 2020, month: 1}
      ])
    end

    it "adds multiple dynamic processes to the execution" do
      runner.enqueue(:posts, year: 2020, month: 1)
      runner.enqueue(:posts, year: 2020, month: 2)

      queue = runner.instance_variable_get(:@execution)
      expect(queue[:posts]).to containing_exactly(
        [an_instance_of(SiteMaps::Process), {year: 2020, month: 1}],
        [an_instance_of(SiteMaps::Process), {year: 2020, month: 2}]
      )
    end
  end

  describe "#enqueue_remaining" do
    it "adds all processes to the execution" do
      runner.enqueue_remaining

      queue = runner.instance_variable_get(:@execution)
      expect(queue).to have_key(:default)
      expect(queue).to have_key(:categories)
      expect(queue).to have_key(:posts)
    end

    it "does not add the process to the execution if static process is already defined" do
      runner.enqueue(:categories)

      queue = runner.instance_variable_get(:@execution)
      expect {
        runner.enqueue_remaining
      }.not_to change(queue[:categories], :size)
    end

    it "enqueues the dynamic process without values" do
      runner.enqueue_remaining

      queue = runner.instance_variable_get(:@execution)
      expect(queue[:posts]).to containing_exactly(
        [an_instance_of(SiteMaps::Process), {}]
      )
    end

    it "does not enqueue the dynamic process if already defined" do
      runner.enqueue(:posts, year: 2020, month: 1)

      expect {
        runner.enqueue_remaining
      }.not_to raise_error
      expect(queue = runner.instance_variable_get(:@execution)).to have_key(:posts)
      expect(queue[:posts]).to containing_exactly(
        [an_instance_of(SiteMaps::Process), {year: 2020, month: 1}]
      )
    end
  end

  describe "#run" do
    it "executes the processes" do
      runner.enqueue(:default)

      queue = []
      runner.instance_variable_get(:@execution).each do |_id, items|
        items.each do |process, kwargs|
          allow(process).to receive(:call).and_call_original
          queue << process
        end
      end

      expect { runner.run }.not_to raise_error
      queue.all? do |process|
        expect(process).to have_received(:call)
      end
    end

    context "when running a partial execution", freeze_at: [2024, 6, 24, 12, 30, 55]  do
      it "preload sitemap index links" do
        runner.enqueue(:default)
        expect(runner.send(:preload_sitemap_index_links?)).to be(true)
        expect(adapter).to receive(:fetch_sitemap_index_links).and_return([
          item = SiteMaps::Sitemap::SitemapIndex::Item.new("https://example.com/site/posts/2024-5/sitemap.xml", Time.new(2024, 5)),
        ])

        runner.run

        expect(adapter.repo.preloaded_index_links).to contain_exactly(
          item
        )
        expect(adapter.sitemap_index.sitemaps.map(&:loc)).to contain_exactly(
          "https://example.com/site/sitemap1.xml",
          "https://example.com/site/posts/2024-5/sitemap.xml"
        )
      end
    end

    context "when some of process fails" do
      let(:adapter) do
        SiteMaps.use(:noop) do
          config.url = "https://example.com/sitemap.xml"
          process do |s|
            s.add("/index.html")
          end
          process(:await) do |s|
            sleep 0.1
            s.add("/await.html")
          end
          process(:failure) do
            raise ArgumentError, "Failure"
          end
        end
      end

      it "interrupts the execution when a process fails" do
        runner = described_class.new(adapter, max_threads: 2)
        runner.enqueue(:failure)
        runner.enqueue(:await)
        runner.enqueue(:default)
        execution = runner.instance_variable_get(:@execution)

        failure = execution[:failure].first.first
        default = execution[:default].first.first
        allow(failure).to receive(:call).and_call_original
        allow(default).to receive(:call).and_call_original

        expect { runner.run }.to raise_error(SiteMaps::RunnerError).with_message(<<~MSG)
          Errors occurred while processing sitemap:
            * Process[failure] error: Failure
        MSG

        expect(failure).to have_received(:call)
        expect(default).not_to have_received(:call)
      end
    end
  end

  describe "#preload_sitemap_index_links?" do
    subject(:preload_links?) { runner.send(:preload_sitemap_index_links?) }

    context "when the runner execution is empty" do
      it "returns false" do
        expect(runner.instance_variable_get(:@execution)).to be_empty
        expect(preload_links?).to be(false)
      end
    end

    context "when the adapter only have static processes" do
      let(:adapter) do
        SiteMaps.use(:noop) do
          config.url = "https://example.com/sitemap.xml"
          process { |s| s.add("/index.html") }
          process(:news) { |s| s.add("/news.html") }
        end
      end

      it "returns false when all the processes are enqueued" do
        runner.enqueue_all

        expect(preload_links?).to be(false)
      end

      it "returns true when not all the processes are enqueued" do
        runner.enqueue(:news)

        expect(preload_links?).to be(true)
      end
    end

    context "when the adapter only have dynamic processes" do
      let(:adapter) do
        SiteMaps.use(:noop) do
          config.url = "https://example.com/sitemap.xml"
          process { |s| s.add("/index.html") }
          process(:posts, "posts/%{year}/sitemap.xml", year: 2024) do |s, year:|
            s.add("/posts/#{year}/index.html")
          end
        end
      end

      it "returns true even when all the processes are enqueued" do
        runner.enqueue(:default)
        runner.enqueue(:posts, year: 2024)

        expect(preload_links?).to be(true)
      end

      it "returns true when not all the processes are enqueued" do
        runner.enqueue(:default)

        expect(preload_links?).to be(true)
      end
    end
  end
end
