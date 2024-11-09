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
  end
end
