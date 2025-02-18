# frozen_string_literal: true

module SiteMaps
  module Runner::EventListener
    extend Primitive::Output

    module_function

    def [](event_name)
      method_name = Primitive::String.new(event_name).underscore.to_sym
      return unless respond_to?(:"on_#{method_name}")

      method(:"on_#{method_name}")
    end

    def on_sitemaps_enqueue_process(event)
      process = event[:process]
      kwargs = event[:kwargs]
      location = process.location(**kwargs)
      print_message(
        "[%<id>s] Enqueue process %<name>s#{" at %<location>s" if location}",
        id: process.id,
        name: colorize(process.name, :bold),
        location: colorize(location, :lightgray)
      )
      if kwargs.any?
        print_message("     └──── Context: {%<kwargs>s}", kwargs: kwargs.map { |k, v| "#{k}: #{v.inspect}" }.join(", "))
      end
    end

    def on_sitemaps_before_process_execution(event)
      process = event[:process]
      kwargs = event[:kwargs]
      location = process.location(**kwargs)
      print_message(
        "[%<id>s] Executing process %<name>s#{" at %<location>s" if location}",
        id: process.id,
        name: colorize(process.name, :bold),
        location: colorize(location, :lightgray)
      )
      if kwargs.any?
        print_message("     └──── Context: {%<kwargs>s}", kwargs: kwargs.map { |k, v| "#{k}: #{v.inspect}" }.join(", "))
      end
    end

    def on_sitemaps_process_execution(event)
      process = event[:process]
      kwargs = event[:kwargs]
      location = process.location(**kwargs)
      print_message(
        "[%<id>s][%<runtime>s] Executed process %<name>s#{" at %<location>s" if location}",
        id: process.id,
        name: colorize(process.name, :bold),
        location: colorize(location, :lightgray),
        runtime: formatted_runtime(event[:runtime])
      )
      if kwargs.any?
        print_message("     └──── Context: {%<kwargs>s}", kwargs: kwargs.map { |k, v| "#{k}: #{v.inspect}" }.join(", "))
      end
    end

    def on_sitemaps_finalize_urlset(event)
      process = event[:process]
      links_count = event[:links_count]
      news_count = event[:news_count]
      url = event[:url]
      text = +"[%<id>s][%<runtime>s] Finalize URLSet with "
      text << "%<links>d links" if links_count > 0
      text << " and " if links_count > 0 && news_count > 0
      text << "%<news>d news" if news_count > 0
      text << " URLs at %<url>s"

      print_message(
        text,
        id: process.id,
        links: links_count,
        news: news_count,
        url: colorize(url, :lightgray),
        runtime: formatted_runtime(event[:runtime])
      )
    end
  end
end
