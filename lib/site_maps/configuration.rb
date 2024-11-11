# frozen_string_literal: true

module SiteMaps
  class << self
    def config
      @config ||= Configuration.new
      yield(@config) if block_given?
      @config
    end
    alias_method :configure, :config
  end

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

    attribute :host
    attribute :main_filename, default: "sitemap.xml"
    attribute :directory, default: "/tmp/sitemaps"

    def initialize(**options)
      self.class.attributes.merge(options).each do |key, value|
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
  end
end
