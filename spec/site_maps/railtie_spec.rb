# frozen_string_literal: true

require "spec_helper"

module DummyRails
  module URLHelpers
    def posts_path
      "/posts"
    end
  end

  class Railtie
    class << self
      def initializer(name, &block)
        @initializer ||= {}
        @initializer[name] = block
      end

      def initialize!(name)
        @initializer[name].call
      end
    end
  end

  module_function

  def application
    require "ostruct"
    OpenStruct.new(routes: OpenStruct.new(url_helpers: URLHelpers))
  end
end

RSpec.describe SiteMaps::Runner do
  before do
    stub_const("Rails", DummyRails)
    allow(Kernel).to receive(:require).with("rails/railtie").and_return(true)
    load File.expand_path("../../lib/site_maps/railtie.rb", __dir__)
    SiteMaps::Railtie.initialize!("site_maps.named_routes")
  end

  it "adds route method to all adapters" do
    adapter = SiteMaps.use(:noop) do
      config.url = "https://example.com/sitemap.xml"
      process do |s|
        s.add route.posts_path
      end
    end
    expect(adapter).to respond_to(:route)

    builder = SiteMaps::SitemapBuilder.new(adapter: adapter)
    allow(builder).to receive(:add).and_call_original

    adapter.processes[:default].call(builder)
    expect(builder.send(:url_set).links_count).to eq(1)
    expect(builder).to have_received(:add).with("/posts")
  end
end
