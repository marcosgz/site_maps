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

module SiteMaps::Primitives
  class String < ::String
    def classify
      new_str = if defined?(Dry::Inflector)
        Dry::Inflector.new.classify(self)
      elsif defined?(ActiveSupport::Inflector)
        ActiveSupport::Inflector.classify(self)
      else
        split("_").map(&:capitalize).join
      end

      self.class.new(new_str)
    end

    def underscore
      new_str = sub(/^::/, "")
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
  end
end
