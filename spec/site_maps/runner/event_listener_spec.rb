# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Runner::EventListener do
  subject(:call!) do
    described_class[event_id].call(event)
  end

  let(:runner) do
    SiteMaps.generate(config_file: fixture_path("noop_sitemap_config.rb"))
  end
  let(:adapter) { runner.adapter }
  let(:event) do
    SiteMaps::Notification::Event.new(event_id, payload)
  end
  let(:payload) { {} }

  describe ".[]" do
    it "returns event method" do
      expect(described_class["sitemaps.enqueue_process"]).to eq(described_class.method(:on_sitemaps_enqueue_process))
    end

    it "returns nil when listener does not implement the event method" do
      expect(described_class["sitemaps.runner.missing"]).to be_nil
    end
  end

  describe ".on_sitemaps_enqueue_process" do
    let(:event_id) { "sitemaps.enqueue_process" }

    context "with a static process" do
      let(:process) { adapter.processes[:default] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}] Enqueue process #{colorize("default", :bold)}
        MSG
      end
    end

    context "with a static process with a location" do
      let(:process) { adapter.processes[:categories] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
        [#{process.id}] Enqueue process #{colorize("categories", :bold)} at #{colorize("categories/sitemap.xml", :lightgray)}
        MSG
      end
    end

    context "with a dynamic process" do
      let(:process) { adapter.processes[:posts] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {year: 2024, month: 11}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}] Enqueue process #{colorize("posts", :bold)} at #{colorize("posts/2024-11/sitemap.xml", :lightgray)}
               └──── Context: {year: 2024, month: 11}
        MSG
      end
    end
  end

  describe ".on_sitemaps_before_process_execution" do
    let(:event_id) { "sitemaps.before_process_execution" }

    context "with a static process" do
      let(:process) { adapter.processes[:default] }
      let(:payload) do
        {
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}] Executing process #{colorize("default", :bold)}
        MSG
      end
    end

    context "with a static process with a location" do
      let(:process) { adapter.processes[:categories] }
      let(:payload) do
        {
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}] Executing process #{colorize("categories", :bold)} at #{colorize("categories/sitemap.xml", :lightgray)}
        MSG
      end
    end

    context "with a dynamic process" do
      let(:process) { adapter.processes[:posts] }
      let(:payload) do
        {
          process: process,
          kwargs: {year: 2024, month: 11}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}] Executing process #{colorize("posts", :bold)} at #{colorize("posts/2024-11/sitemap.xml", :lightgray)}
               └──── Context: {year: 2024, month: 11}
        MSG
      end
    end
  end

  describe ".on_sitemaps_process_execution" do
    let(:event_id) { "sitemaps.process_execution" }

    context "with a static process" do
      let(:process) { adapter.processes[:default] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}][#{formatted_runtime(1.32)}] Executed process #{colorize("default", :bold)}
        MSG
      end
    end

    context "with a static process with a location" do
      let(:process) { adapter.processes[:categories] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}][#{formatted_runtime(1.32)}] Executed process #{colorize("categories", :bold)} at #{colorize("categories/sitemap.xml", :lightgray)}
        MSG
      end
    end

    context "with a dynamic process" do
      let(:process) { adapter.processes[:posts] }
      let(:payload) do
        {
          runtime: 1.32,
          process: process,
          kwargs: {year: 2024, month: 11}
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{process.id}][#{formatted_runtime(1.32)}] Executed process #{colorize("posts", :bold)} at #{colorize("posts/2024-11/sitemap.xml", :lightgray)}
               └──── Context: {year: 2024, month: 11}
        MSG
      end
    end
  end

  describe ".on_sitemaps_finalize_urlset" do
    let(:event_id) { "sitemaps.finalize_urlset" }
    let(:process) { adapter.processes[:default] }

    let(:payload) do
      {
        runtime: 1.32,
        links_count: 10,
        news_count: 2,
        url: "https://example.com/site/sitemap1.xml",
        process: process,
      }
    end

    it "prints message" do
      expect { call! }.to output(<<~MSG).to_stdout
        [#{process.id}][#{formatted_runtime(1.32)}] Finalize URLSet with 10 links and 2 news URLs at #{colorize("https://example.com/site/sitemap1.xml", :lightgray)}
      MSG
    end
  end

  def colorize(*args)
    SiteMaps::Primitives::Output.colorize(*args)
  end

  def formatted_runtime(runtime)
    SiteMaps::Primitives::Output.formatted_runtime(runtime)
  end
end
