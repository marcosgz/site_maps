# frozen_string_literal: true

require "securerandom"

module SiteMaps
  Process = Concurrent::ImmutableStruct.new(:name, :location_template, :kwargs_template, :block) do
    def id
      @id ||= SecureRandom.hex(4)
    end

    def location(**kwargs)
      return unless location_template

      location_template % keyword_arguments(kwargs)
    end

    def call(builder, **kwargs)
      return unless block

      block.call(builder, **keyword_arguments(kwargs))
    end

    def static?
      !dynamic?
    end

    def dynamic?
      kwargs_template.is_a?(Hash) && kwargs_template.any?
    end

    def keyword_arguments(given)
      (kwargs_template || {}).merge(given || {})
    end
  end
end
