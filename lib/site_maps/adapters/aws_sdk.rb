# frozen_string_literal: true

module SiteMaps::Adapters
  class AwsSdk < Adapter
    def write(url, raw_data, **options)
      location = Location.new(config.directory, url)
      local_storage.write(location, raw_data)
      s3_storage.upload(location, **options)
    end

    def read(url)
      location = Location.new(config.directory, url)
      s3_storage.read(location)
    end

    def delete(url)
      location = Location.new(config.directory, url)
      s3_storage.delete(location)
    end

    def list_sitemaps
      prefix = config.remote_sitemap_directory
      prefix = "#{prefix}/" unless prefix.empty?
      s3_storage.list(prefix).filter_map do |key, last_modified|
        next unless key.end_with?(".xml", ".xml.gz")

        SiteMaps::Builder::SitemapIndex::Item.new("#{config.base_uri}/#{key}", last_modified)
      end
    end

    private

    def local_storage
      @local_storage ||= SiteMaps::Adapters::FileSystem::Storage.new
    end

    def s3_storage
      @s3_storage ||= SiteMaps::Adapters::AwsSdk::Storage.new(config)
    end
  end
end
