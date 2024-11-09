# frozen_string_literal: true

module SiteMaps::Primitives
  class Array < ::Array
    def self.wrap(object)
      if object.nil?
        []
      elsif object.respond_to?(:to_ary)
        object.to_ary || [object]
      else
        [object]
      end
    end
  end
end
