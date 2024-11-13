# SiteMaps

SiteMaps is a gem that helps you to generate sitemaps for your Rails application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'site_maps'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install site_maps
```

## Usage

prototyping DSL:

File System

```ruby
SiteMaps.use(:file_system) do
  include_module(Rails.application.routes.url_helpers)

  configure do |config|
    config.url = 'https://example.com/sitemaps/sitemap.xml.gz' # Location of main sitemap index file
    config.directory = 'public/sitemaps'
  end

  # Each process will be executed in a separate thread in order to improve performance
  process do |s|
    s.add(root_path, priority: 1.0, changefreq: 'daily')
    s.add(about_path, priority: 0.9, changefreq: 'weekly')
  end

  process :categories, "categories/sitemap.xml" do |s|
    Category.find_each do |category|
      s.add(category_path(category), priority: 0.7)
    end
  end

  process :posts, "posts/%{year}-%{month}/sitemap.xml", year: Date.today.year, month: Date.today.month do |s, year, month|
    Post.where(year: year, month: month).find_each do |post|
      s.add(post_path(post), priority: 0.8)
    end
  end
end
```

AWS S3

```ruby
aws_sdk_options = {
  bucket: 'my-bucket',
  region: 'us-east-1',
  access_key_id: 'my-access-key',
  secret_access_key: 'my-secret-key'
  # Optional parameters (default values)
  acl: 'public-read',
  cache_control: 'private, max-age=0, no-cache',
}

SiteMaps.use(:aws_sdk, **aws_sdk_options) do |s|
  include Rails.application.routes.url_helpers

  configure do |config|
    config.url = 'https://my-bucket.s3.amazonaws.com/sitemaps/sitemap.xml.gz'
  end

  sitemap do |s|
    s.add(root_path, priority: 1.0, changefreq: 'daily')
    s.add(about_path, priority: 0.9, changefreq: 'weekly')
  end
  # ...
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/site_maps.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
