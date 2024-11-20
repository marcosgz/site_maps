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

  describe '.[]' do
    it 'returns event method' do
      expect(described_class['sitemaps.runner.enqueue']).to eq(described_class.method(:on_sitemaps_runner_enqueue))
    end

    it 'returns nil when listener does not implement the event method' do
      expect(described_class['sitemaps.runner.missing']).to eq(nil)
    end
  end

  describe ".on_sitemaps_runner_enqueue" do
    let(:event_id) { "sitemaps.runner.enqueue" }

    context "with a static process" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:default],
          kwargs: {},
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Enqueue process #{colorize("default", :bold)}
        MSG
      end
    end

    context "with a static process with a location" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:categories],
          kwargs: {},
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Enqueue process #{colorize("categories", :bold)} at #{colorize("categories/sitemap.xml", :lightgray)}
        MSG
      end
    end

    context "with a dynamic process" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:posts],
          kwargs: { year: 2024, month: 11 },
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Enqueue process #{colorize("posts", :bold)} at #{colorize("posts/2024-11/sitemap.xml", :lightgray)}
          --> Keyword Arguments: {year: 2024, month: 11}
        MSG
      end
    end
  end

  describe ".on_sitemaps_runner_execute" do
    let(:event_id) { "sitemaps.runner.execute" }

    context "with a static process" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:default],
          kwargs: {},
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Execute process #{colorize("default", :bold)}
        MSG
      end
    end

    context "with a static process with a location" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:categories],
          kwargs: {},
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Execute process #{colorize("categories", :bold)} at #{colorize("categories/sitemap.xml", :lightgray)}
        MSG
      end
    end

    context "with a dynamic process" do
      let(:payload) do
        {
          runtime: 1.32,
          process: adapter.processes[:posts],
          kwargs: { year: 2024, month: 11 },
        }
      end

      it "prints message" do
        expect { call! }.to output(<<~MSG).to_stdout
          [#{formatted_runtime(1.32)}] Execute process #{colorize("posts", :bold)} at #{colorize("posts/2024-11/sitemap.xml", :lightgray)}
          --> Keyword Arguments: {year: 2024, month: 11}
        MSG
      end
    end
  end

  describe ".on_sitemaps_builder_finalize_urlset" do
    let(:event_id) { "sitemaps.builder.finalize_urlset" }

    let(:payload) do
      {
        runtime: 1.32,
        links_count: 10,
        news_count: 2,
        url: "https://example.com/site/sitemap1.xml",
      }
    end

    it "prints message" do
      expect { call! }.to output(<<~MSG).to_stdout
        [#{formatted_runtime(1.32)}] Finalize URLSet with 10 links and 2 news URLs at #{colorize("https://example.com/site/sitemap1.xml", :lightgray)}
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

