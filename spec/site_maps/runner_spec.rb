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
  end
end
