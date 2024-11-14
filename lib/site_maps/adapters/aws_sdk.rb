# frozen_string_literal: true

module SiteMaps::Adapters
  class AwsSdk < Adapter
    def write(url, raw_data, **metadata)
      location = Location.new(config.directory, url)
      local_storage.write(location, raw_data)
      s3_storage.upload(location, **metadata)
    end

    def read(url)
      location = Location.new(config.directory, url)
      s3_storage.read(location.remote_path)
    end

    def delete(url)
      location = Location.new(config.directory, url)
      s3_storage.delete(location.remote_path)
    end

    private

    def local_storage
      @local_storage ||= SiteMaps::Adapters::FileSystem::Storage.new
    end

    def s3_storage
      @s3_storage ||= Storage.new(config)
    end
  end
end
