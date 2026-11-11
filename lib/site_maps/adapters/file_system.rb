# frozen_string_literal: true

module SiteMaps::Adapters
  class FileSystem < Adapter
    def write(url, raw_data, **)
      location = Location.new(config.directory, url)
      storage.write(location, raw_data)
    end

    def read(url)
      location = Location.new(config.directory, url)
      storage.read(location)
    end

    def delete(url)
      location = Location.new(config.directory, url)
      storage.delete(location)
    end

    def list_sitemaps
      root = Pathname.new(config.directory)
      pattern = root.join(config.remote_sitemap_directory, "**", "*.{xml,xml.gz}").to_s
      Dir.glob(pattern).map do |path|
        relative = Pathname.new(path).relative_path_from(root).to_s
        SiteMaps::Builder::SitemapIndex::Item.new("#{config.base_uri}/#{relative}", File.mtime(path))
      end
    end

    private

    def storage
      @storage ||= self.class::Storage.new
    end
  end
end
