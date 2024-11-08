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
      new_str = case
      when defined?(Dry::Inflector)
        Dry::Inflector.new.classify(self)
      when defined?(ActiveSupport::Inflector)
        ActiveSupport::Inflector.classify(self)
      else
        self.split("_").map(&:capitalize).join
      end

      self.class.new(new_str)
    end
  end
end
