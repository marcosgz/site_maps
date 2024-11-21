# frozen_string_literal: true

module SiteMaps::Builder
  module Normalizer
    extend self

    def format_float(value)
      value.is_a?(String) ? value : ("%0.1f" % value)
    end

    def yes_or_no(value)
      if value.is_a?(String) && value.match?(/\A(yes|no)\z/i)
        value.downcase
      else
        value ? "yes" : "no"
      end
    end

    def yes_or_no_with_default(value, default)
      value.nil? ? yes_or_no(default) : yes_or_no(value)
    end

    def w3c_date(date)
      if date.is_a?(String)
        date
      elsif date.respond_to?(:iso8601)
        date.iso8601.sub(/Z$/i, "+00:00")
      elsif date.is_a?(Date) && defined?(DateTime) && !date.is_a?(DateTime)
        date.strftime("%Y-%m-%d")
      else
        zulutime = if defined?(DateTime) && date.is_a?(DateTime)
          date.new_offset(0)
        elsif date.respond_to?(:utc)
          date.utc
        elsif date.is_a?(Integer)
          Time.at(date).utc
        end

        if zulutime
          zulutime.strftime("%Y-%m-%dT%H:%M:%S+00:00")
        else
          zone = date.strftime("%z").insert(-3, ":")
          date.strftime("%Y-%m-%dT%H:%M:%S") + zone
        end
      end
    end
  end
end
