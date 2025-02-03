# frozen_string_literal: true

begin
  require "dry/inflector"
rescue LoadError
  # noop
end

begin
  require "active_support/inflector"
rescue LoadError
  # noop
end

module SiteMaps::Primitive
  class String < ::String
    def self.inflector
      return @inflector if defined?(@inflector)

      @inflector = if defined?(::ActiveSupport::Inflector)
        ::ActiveSupport::Inflector
      elsif defined?(::Dry::Inflector)
        ::Dry::Inflector.new
      end
    end

    def classify
      new_str = inflector&.classify(self) || split("/").collect do |c|
        c.split("_").collect(&:capitalize).join
      end.join("::")

      self.class.new(new_str)
    end

    def constantize
      inflector&.constantize(self) || Object.const_get(self)
    end

    def underscore
      new_str = inflector&.underscore(self) || sub(/^::/, "")
        .gsub("::", "/")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .tr(".", "_")
        .gsub(/\s/, "_")
        .gsub(/__+/, "_")
        .downcase

      self.class.new(new_str)
    end

    def pluralize
      new_str = inflector&.pluralize(self) || begin
        # dummy pluralize
        if /y$/.match?(self)
          sub(/y$/, "ies")
        elsif /s$/.match?(self)
          self
        else
          self + "s"
        end
      end

      new_str.is_a?(self.class) ? new_str : self.class.new(new_str)
    end

    def singularize
      new_str = inflector&.singularize(self) || begin
        # dummy singularize
        if /ies$/.match?(self)
          sub(/ies$/, "y")
        elsif /s$/.match?(self)
          sub(/s$/, "")
        else
          self
        end
      end

      new_str.is_a?(self.class) ? new_str : self.class.new(new_str)
    end

    def camelize(uppercase_first_letter = true)
      new_str = inflector&.camelize(self, uppercase_first_letter) || begin
        # dummy camelize
        str = to_s
        str = str.sub(/^[a-z\d]*/) { $&.capitalize }
        str = str.tr("-", "_")
        str = str.gsub(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
        str = str.gsub("/", "::")
        unless uppercase_first_letter
          str = str.sub(/^[A-Z]*/) { $&.downcase }
        end
        str
      end

      self.class.new(new_str)
    end

    protected

    def inflector
      self.class.inflector
    end
  end
end
