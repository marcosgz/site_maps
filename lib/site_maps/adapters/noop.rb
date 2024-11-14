# frozen_string_literal: true

module SiteMaps::Adapters
  class Noop < Adapter
    def write(_url, _raw_data, **_kwargs)
    end

    def read(_url)
    end
  end
end
