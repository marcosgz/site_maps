# frozen_string_literal: true

module SiteMaps::Adapters
  class Noop < Adapter
    def write(_url, _raw_data, **_kwargs)
    end

    def read(_url)
    end

    def delete(_url)
    end

    def fetch_sitemap_index_links
      []
    end
  end
end
