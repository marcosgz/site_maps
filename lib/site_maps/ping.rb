# frozen_string_literal: true

require "net/http"

module SiteMaps
  module Ping
    ENGINES = {
      bing: "https://www.bing.com/ping?sitemap=%{url}"
    }.freeze

    class << self
      def ping(sitemap_url, engines: nil)
        engines ||= ENGINES
        encoded_url = ERB::Util.url_encode(sitemap_url)

        engines.each_with_object({}) do |(name, url_template), results|
          ping_url = url_template % {url: encoded_url}
          uri = URI.parse(ping_url)

          response = Net::HTTP.get_response(uri)
          results[name] = {status: response.code.to_i, url: ping_url}

          SiteMaps.logger.info("[SiteMaps] Pinged #{name}: #{response.code} - #{ping_url}")
        rescue => e
          results[name] = {status: nil, error: e.message, url: ping_url}
          SiteMaps.logger.warn("[SiteMaps] Failed to ping #{name}: #{e.message}")
        end
      end

      def default_engines
        ENGINES
      end
    end
  end
end
