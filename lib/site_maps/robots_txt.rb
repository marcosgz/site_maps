# frozen_string_literal: true

module SiteMaps
  module RobotsTxt
    class << self
      def sitemap_directive(url = nil)
        url ||= SiteMaps.current_adapter&.config&.url
        raise ArgumentError, "No sitemap URL provided and no adapter configured" unless url

        "Sitemap: #{url}"
      end

      def render(sitemap_url: nil, extra_directives: [])
        lines = ["User-agent: *", "Allow: /"]
        extra_directives.each { |d| lines << d }
        lines << sitemap_directive(sitemap_url)
        lines.join("\n") + "\n"
      end
    end
  end
end
