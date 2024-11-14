# frozen_string_literal: true

module SiteMaps::Adapters
  class Noop < Adapter
    def write(_location, _raw_data)
    end
  end
end
