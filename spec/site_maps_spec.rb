# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps do
  it "has a version number" do
    expect(SiteMaps::VERSION).not_to be_nil
  end

  describe ".use" do
    it "returns an instance of the adapter" do
      adapter = described_class.use(:file_system, directory: "tmp")
      expect(adapter).to be_a(SiteMaps::Adapters::FileSystem)
      expect(adapter.config.directory).to eq("tmp")
      expect(described_class.current_adapter).to eq(adapter)
    end

    it "raises an error if the adapter is not found" do
      expect {
        described_class.use(:unknown)
      }.to raise_error(SiteMaps::AdapterNotFound)
    end

    it "uses the given adapter class" do
      adapter = Class.new(SiteMaps::Adapters::Adapter)
      config = Class.new(SiteMaps::Configuration)
      adapter.const_set(:Config, config)

      expect(described_class.use(adapter)).to be_an_instance_of(adapter)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.url = "https://example.com/sitemap.xml"
        config.directory = "tmp"
      end

      expect(described_class.config.url).to eq("https://example.com/sitemap.xml")
      expect(described_class.config.directory).to eq("tmp")
    end
  end

  describe ".current_adapter" do
    after do
      described_class.instance_variable_set(:@current_adapter, nil)
    end

    it "returns the current adapter" do
      adapter = described_class.use(:file_system, directory: "tmp")
      expect(described_class.current_adapter).to eq(adapter)
    end
  end

  describe ".generate" do
    before do
      described_class.instance_variable_set(:@current_adapter, nil)
    end

    it "delegates to the current adapter" do
      described_class.use(:file_system, directory: "tmp")
      expect(described_class.generate).to be_an_instance_of(SiteMaps::Runner)
    end

    it "raises an error if no adapter is set" do
      expect {
        described_class.generate
      }.to raise_error(SiteMaps::AdapterNotSetError)
    end

    it "loads the configuration file" do
      runner = described_class.generate(config_file: fixture_path("noop_sitemap_config.rb"))
      expect(runner.adapter).to be_an_instance_of(SiteMaps::Adapters::Noop)
      expect(described_class.current_adapter).to be(runner.adapter)
    end
  end

  describe ".define with context" do
    before do
      described_class.instance_variable_set(:@current_adapter, nil)
      described_class.instance_variable_set(:@definition, nil)
    end

    let(:config_path) do
      path = File.join(Dir.tmpdir, "context_aware_sitemap_#{SecureRandom.hex(4)}.rb")
      File.write(path, <<~RUBY)
        SiteMaps.define do |site|
          use(:noop) do
            config.url = "https://\#{site[:domain]}/sitemap.xml"
            config.directory = site[:directory]
          end
        end
      RUBY
      path
    end

    after { File.delete(config_path) if File.exist?(config_path) }

    it "passes context to the definition block" do
      site = {domain: "example.com", directory: "/tmp/site1"}

      runner = described_class.generate(config_file: config_path, context: site)

      expect(runner.adapter.config.url).to eq("https://example.com/sitemap.xml")
      expect(runner.adapter.config.directory).to eq("/tmp/site1")
    end

    it "creates isolated adapters per site" do
      site_a = {domain: "a.com", directory: "/tmp/a"}
      site_b = {domain: "b.com", directory: "/tmp/b"}

      runner_a = described_class.generate(config_file: config_path, context: site_a)
      url_a = runner_a.adapter.config.url

      runner_b = described_class.generate(config_file: config_path, context: site_b)

      expect(url_a).to eq("https://a.com/sitemap.xml")
      expect(runner_b.adapter.config.url).to eq("https://b.com/sitemap.xml")
    end

    it "accepts multiple context args as an array" do
      path = File.join(Dir.tmpdir, "multi_context_#{SecureRandom.hex(4)}.rb")
      File.write(path, <<~RUBY)
        SiteMaps.define do |site, locale|
          use(:noop) do
            config.url = "https://\#{site[:domain]}/\#{locale}/sitemap.xml"
          end
        end
      RUBY

      runner = described_class.generate(config_file: path, context: [{domain: "example.com"}, "en"])

      expect(runner.adapter.config.url).to eq("https://example.com/en/sitemap.xml")
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  describe ".logger" do
    it "returns the default logger" do
      expect(described_class.logger).to be_a(Logger)
    end
  end

  describe ".logger=" do
    it "sets the logger" do
      logger = Logger.new($stdout)
      described_class.logger = logger
      expect(described_class.logger).to be(logger)
    end
  end
end
