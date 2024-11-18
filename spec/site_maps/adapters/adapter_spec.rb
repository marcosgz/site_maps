# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Adapters::Adapter do
  # let(:adapter_config) do
  #   Class.new(SiteMaps::Configuration)
  # end
  # before do
  #   stub_const("SiteMaps::Adapters::Adapter::Config", adapter_config)
  # end

  describe ".config_class" do
    subject(:config_class) { described_class.config_class }

    let(:adapter_class) do
      Class.new(described_class)
    end

    context "when the adapter has a Config class" do
      let(:adapter_config) do
        Class.new(SiteMaps::Configuration)
      end

      before do
        stub_const("SiteMaps::Adapters::Adapter::Config", adapter_config)
      end

      it "returns the Config class" do
        expect(adapter_class.config_class).to eq(adapter_config)
      end
    end

    context "when the adapter does not have a Config class" do
      it "returns the default configuration" do
        expect(adapter_class.config_class).to eq(SiteMaps::Configuration)
      end
    end
  end

  describe "#initialize" do
    subject(:adapter) do
      described_class.new
    end

    it "has a sitemap_index" do
      expect(adapter.sitemap_index).to be_a(SiteMaps::Sitemap::SitemapIndex)
    end

    context "when initialized with options" do
      subject(:adapter) do
        described_class.new(url: "https://example.com/sitemap.xml")
      end

      it "has options" do
        expect(adapter.config.url).to eq("https://example.com/sitemap.xml")
      end
    end

    context "when initialized with a block" do
      it "evaluates the block" do
        instance = described_class.new do
          configure { |c| c.url = "https://example.com/sitemap.xml" }
          config.directory = "/tmp"

          posts_index = "/posts.html"

          process(:posts) do |sitemap, **|
            sitemap.add(posts_index)
          end
        end

        expect(instance.config.url).to eq("https://example.com/sitemap.xml")
        expect(instance.config.directory).to eq("/tmp")
        expect(instance.processes).to have_key(:posts)
      end
    end
  end

  describe "#config" do
    subject(:adapter) do
      described_class.new
    end

    it "has a configuration" do
      expect(adapter.config).to be_a(SiteMaps::Configuration)
    end
  end

  describe "#configure" do
    subject(:adapter) do
      described_class.new
    end

    it "yields self" do
      config = adapter.config
      expect { |b| adapter.configure(&b) }.to yield_with_args(config)
    end
  end

  describe "#process" do
    subject(:adapter) { described_class.new }

    it "creates a process" do
      adapter.process { |*, **| raise("do not call") }
      expect(adapter.processes).to have_key(:default)
      expect(adapter.processes[:default].block).to be_a(Proc)
    end

    it "raises an error if the process is already defined" do
      adapter.process { |*, **| }
      expect { adapter.process { |*, **| } }.to raise_error(ArgumentError)
    end

    it "creates a process with the given name" do
      adapter.process(:posts) { |*, **| }
      expect(adapter.processes).to have_key(:posts)
    end

    it "creates a process with the given location" do
      adapter.process(:posts, "posts/sitemap.xml") { |*, **| ra se("do not call") }
      expect(adapter.processes[:posts].block).to be_a(Proc)
      expect(adapter.processes[:posts].location).to eq("posts/sitemap.xml")
    end

    it "creates a dynamic process" do
      adapter.process(:posts, "posts/%{year}/sitemap.xml", year: 2020) { |*, **| raise("do not call") }
      expect(adapter.processes[:posts].location).to eq("posts/2020/sitemap.xml")
      expect(adapter.processes[:posts].location(year: 2024)).to eq("posts/2024/sitemap.xml")
    end
  end

  describe "#maybe_inline_urlset?" do
    subject(:adapter) { described_class.new }

    it "is false when there are multiple processes" do
      adapter.process { |*, **| }
      adapter.process(:posts) { |*, **| }
      expect(adapter.send(:maybe_inline_urlset?)).to be(false)
    end

    it "is false when the process is not static" do
      adapter.process(:dinamic, "posts/%{year}/sitemap.xml", year: 2020) { |*, **| }
      expect(adapter.send(:maybe_inline_urlset?)).to be(false)
    end

    it "is true when there is a single static process" do
      adapter.process { |*, **| }
      expect(adapter.send(:maybe_inline_urlset?)).to be(true)
    end
  end

  describe "#write" do
    subject(:adapter) { described_class.new }

    it "raises an error" do
      expect { adapter.write("https://example.com/sitemap.xml", "") }.to raise_error(NotImplementedError)
    end
  end

  describe "#read" do
    subject(:adapter) { described_class.new }

    it "raises an error" do
      expect { adapter.read("https://example.com/sitemap.xml") }.to raise_error(NotImplementedError)
    end
  end

  describe "#delete" do
    subject(:adapter) { described_class.new }

    it "raises an error" do
      expect { adapter.delete("https://example.com/sitemap.xml") }.to raise_error(NotImplementedError)
    end
  end

  describe "#repo" do
    subject(:adapter) { described_class.new.tap { |a| a.config.url = "https://example.com/sitemap.xml" } }

    it "returns the repository" do
      expect(repo = adapter.repo).to be_a(SiteMaps::AtomicRepository)
      expect(adapter.repo).to be(repo)
      expect(adapter.repo.main_url).to eq("https://example.com/sitemap.xml")
    end
  end

  describe "#fetch_sitemap_index_links" do
    let(:adapter) { described_class.new.tap { |a| a.config.url = "https://example.com/sitemap.xml" } }

    it "calls the method on the configuration" do
      expect(adapter.config).to receive(:fetch_sitemap_index_links).and_return([
        SiteMaps::Sitemap::SitemapIndex::Item.new("https://example.com/sitemap1.xml", Time.now)
      ])

      expect((links = adapter.fetch_sitemap_index_links).size).to eq(1)
      expect(links).to all(be_a(SiteMaps::Sitemap::SitemapIndex::Item))
    end
  end

  describe "#include_module" do
    let(:adapter) { described_class.new }
    let(:mod) do
      Module.new do
        def foo
          "foo"
        end
      end
    end

    it "includes the module" do
      adapter.include_module(mod)
      expect(adapter).to respond_to(:foo)
    end
  end
end
