# frozen_string_literal: true

module SiteMaps
  class Configuration
    class << self
      def attributes
        @attributes || {}
      end

      def attribute(name, default: nil)
        @attributes ||= {}
        @attributes[name] = default

        unless method_defined?(name)
          define_method(name) do
            instance_variable_get(:"@#{name}")
          end
        end

        unless method_defined?(:"#{name}=")
          define_method(:"#{name}=") do |value|
            instance_variable_set(:"@#{name}", value)
          end
        end

        unless method_defined?(:"#{name}?")
          define_method(:"#{name}?") do
            !!send(name)
          end
        end
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@attributes, attributes.dup)
      end
    end

    attribute :url
    attribute :directory, default: "/tmp/sitemaps"

    def initialize(**options)
      default_attributes.merge(options).each do |key, value|
        send(:"#{key}=", value)
      rescue NoMethodError
        raise ConfigurationError, <<~ERROR
          Unknown configuration option: #{key}
        ERROR
      end
    end

    def becomes(klass, **options)
      klass.new(**to_h, **options)
    end

    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete("@").to_sym] = instance_variable_get(var)
      end
    end

    def url
      @url || validate_url!
    end

    def host
      ::URI.parse(url).host
    end

    def local_sitemap_path
      filename = ::File.basename(url)
      Pathname.new(directory).join(filename)
    end

    def read_index_sitemaps
      doc = SiteMaps::SitemapReader.new(local_sitemap_path.exist? ? local_sitemap_path : url).to_doc

      doc.css("sitemapindex sitemap").map do |url|
        SiteMaps::Sitemap::SitemapIndex::Item.new(
          url.at_css("loc").text,
          url.at_css("lastmod")&.text,
        )
      end
    rescue SiteMaps::SitemapReader::Error
      []
    end

    def remote_sitemap_directory
      path = ::URI.parse(url).path
      path = path[1..-1] if path.start_with?("/")
      path.split("/")[0..-2].join("/")
    end

    private

    def validate_url!
      return if @url

      raise ConfigurationError, <<~ERROR
        You must set a sitemap URL in your configuration to use the add method.

        Example:
          SiteMaps.configure do |config|
            config.url = "https://example.com/sitemap.xml"
          end
      ERROR
    end

    def default_attributes
      self.class.attributes.each_with_object({}) do |(key, default), hash|
        value = default.respond_to?(:call) ? default.call : default
        hash[key] = value unless value.nil?
      end
    end
  end
end
