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

    private

    def storage
      @storage ||= self.class::Storage.new
    end
  end
end
