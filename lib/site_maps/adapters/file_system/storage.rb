# frozen_string_literal: true

class SiteMaps::Adapters::FileSystem::Storage
  # @param [SiteMaps::Adapters::FileSystem::Location] location
  # @param [String] raw_data
  # @return [void]
  # @raise [SiteMaps::Error] if the path is not a directory
  def write(location, raw_data, **)
    dir = location.directory

    if !File.exist?(dir)
      FileUtils.mkdir_p(dir)
    elsif !File.directory?(dir)
      raise SiteMaps::Error.new("The path #{dir} is not a directory")
    end

    stream = File.open(location.path, "wb")
    if location.gzip?
      gzip(stream, raw_data)
    else
      plain(stream, raw_data)
    end
  end

  # @param [SiteMaps::Adapters::FileSystem::Location] location
  # @return [Array<String, Hash>] The raw data and metadata
  # @raise [SiteMaps::FileNotFoundError] if the file does not exist
  def read(location)
    if location.gzip?
      [Zlib::GzipReader.open(location.path).read, {content_type: "application/gzip"}]
    else
      [File.read(location.path), {content_type: "application/xml"}]
    end
  rescue Zlib::GzipFile::Error
    raise SiteMaps::FileNotFoundError.new("File not found: #{location.path}")
  rescue Errno::ENOENT
    raise SiteMaps::FileNotFoundError.new("File not found: #{location.path}")
  end

  # @param [SiteMaps::Adapters::FileSystem::Location] location
  # @return [void]
  # @raise [SiteMaps::FileNotFoundError] if the file does not exist
  def delete(location)
    File.delete(location.path)
  rescue Errno::ENOENT
    raise SiteMaps::FileNotFoundError.new("File not found: #{location.path}")
  end

  protected

  def gzip(stream, data)
    gz = Zlib::GzipWriter.new(stream)
    gz.write data
    gz.close
  end

  def plain(stream, data)
    stream.write data
    stream.close
  end
end
