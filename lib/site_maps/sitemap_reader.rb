# frozen_string_literal: true

require "open-uri"

module SiteMaps
  class SitemapReader
    Error = Class.new(SiteMaps::Error)
    FileNotFoundError = Class.new(Error)
    MalformedFileError = Class.new(Error)

    def initialize(location)
      @location = Pathname.new(location)
    end

    def read
      if compressed?
        Zlib::GzipReader.new(read_file).read
      else
        read_file.read
      end
    rescue Zlib::GzipFile::Error => _e
      raise MalformedFileError.new("The file #{@location} is not a valid Gzip file")
    end

    def to_doc
      @doc ||= begin
        require "nokogiri"
        Nokogiri::XML(read)
      end
    rescue LoadError
      raise SiteMaps::Error, "Nokogiri is required to parse the XML file"
    end

    protected

    def read_file
      if remote?
        ::URI.parse(@location.to_s).open
      else
        ::File.open(@location, "r")
      end
    rescue Errno::ENOENT
      raise FileNotFoundError.new("The file #{@location} does not exist")
    rescue OpenURI::HTTPError
      raise FileNotFoundError.new("The file #{@location} could not be opened")
    end

    def compressed?
      @location.extname == ".gz"
    end

    def remote?
      %r{^https?://}.match?(@location.to_s)
    end
  end
end
