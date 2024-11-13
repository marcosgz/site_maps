SiteMaps.use(:noop) do
  configure do |config|
    config.url = "https://example.com/site/sitemap.xml"
  end

  process do |s|
    s.add("/index.html")
    s.add("/about.html")
    s.add("/contact.html")
  end

  categories = %w[news sports entertainment]

  process(:categories) do |s|
    categories.each do |category|
      s.add("/#{category}.html")
    end
  end

  process(:posts, "posts/%{year}-%{month}/sitemap.xml", year: 2024, month: nil) do |s, year:, month:|
    s.add("/posts/#{year}/#{month}/index.html")
  end
end
