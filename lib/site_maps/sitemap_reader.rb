# frozen_string_literal: true

require "open-uri"

module SiteMaps
  class SitemapReader
    Error = Class.new(SiteMaps::Error)
    FileNotFound = Class.new(Error)
    MalformedFile = Class.new(Error)

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
      raise MalformedFile.new("The file #{@location} is not a valid Gzip file")
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
      ::URI.open(@location.to_s)
    rescue Errno::ENOENT => e
      raise FileNotFound.new("The file #{@location} does not exist")
    rescue OpenURI::HTTPError => e
      raise FileNotFound.new("The file #{@location} could not be opened")
    end

    def compressed?
      @location.extname == ".gz"
    end
  end
end
