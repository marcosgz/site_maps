# frozen_string_literal: true

module SiteMaps
  class Configuration
    attr_reader :host, :main_filename, :directory

    def initialize(host: nil, main_filename: "sitemap.xml", directory: "/tmp/sitemaps")
      @host = host
      @main_filename = main_filename
      @directory = directory
    end
  end
end
