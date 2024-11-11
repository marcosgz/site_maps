# frozen_string_literal: true

class SiteMaps::Adapters::FileSystem::FileHandler
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def existing_files
    return [] unless config.sitemap_path.exist?
  end

  def write(location, data)
    dir = location.directory
    if !File.exist?(dir)
      FileUtils.mkdir_p(dir)
    elsif !File.directory?(dir)
      raise SitemapError.new("The path #{dir} is not a directory")
    end

    stream = open(location.path, "wb")
    if location.path.to_s =~ /.gz$/
      gzip(stream, raw_data)
    else
      plain(stream, raw_data)
    end
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
