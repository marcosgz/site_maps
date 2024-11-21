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

Create a configuration file where you will define the sitemap logic. You can use the following DSL to define the sitemap generation. Below is the minimum configuration required to generate a sitemap:

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz" # Location of main sitemap index file
    config.directory = "/home/www/public"
  end
  process do |s|
    s.add('/', priority: 1.0, changefreq: "daily")
    s.add('/about', priority: 0.9, changefreq: "weekly")
  end
end
```

After creating the configuration file, you can run the following command to generate the sitemap:

```bash
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue_all
  .run
```

Sitemap links are defined in the `process` block because the gem is designed to generate sitemaps for large websites in parallel. The `process` block will be executed in a separate thread for each process, which will improve the performance of the sitemap generation. Each process can have a unique name and a unique sitemap file location. By omitting the name and the file location, the process will use the `:default` value.

Bellows is an example of a configuration file with multiple processes:

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz" # Location of main sitemap index file
    config.directory = "/home/www/public"
  end
  process do |s|
    s.add('/', priority: 1.0, changefreq: "daily")
    s.add('/about', priority: 0.9, changefreq: "weekly")
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

The `process` block can receive a name and a file location as arguments. The file location can contain placeholders that will be replaced by the values passed to the process block. The `process` block can receive a hash with the values that will be used to replace the placeholders in the file location. It will allow you to incrementally generate sitemaps by year and month, for example.

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue(:posts, year: 2021, month: 1)
  .enqueue(:posts, year: 2021, month: 2)
  .enqueue_remaining # Enqueue all remaining processes (default and categories)
  .run
```

If you are using Rails, you may want to add routes to the sitemap builder. You can use the `include_module` adapter method.

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  include_module Rails.application.routes.url_helpers # It's the same of `extend Rails.application.routes.url_helpers`

  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz" # Location of main sitemap index file
    config.directory = "/home/www/public"
  end
  process do |s|
    s.add(root_path, priority: 1.0, changefreq: "daily")
    s.add(about_path, priority: 0.9, changefreq: "weekly")
  end
end
```

### AWS S3

You can use the AWS S3 adapter to store the sitemaps in an S3 bucket. The configuration is similar to the file system adapter, but you need to provide the AWS SDK options.

```ruby
aws_sdk_options = {
  bucket: "my-bucket",
  region: "us-east-1",
  aws_access_key: ENV["AWS_ACCESS_KEY_ID"],
  aws_secret_key: ENV["AWS_SECRET_ACCESS_KEY"],
  # Optional parameters (default values)
  acl: "public-read",
  cache_control: "private, max-age=0, no-cache",
}

SiteMaps.use(:aws_sdk, **aws_sdk_options) do
  configure do |config|
    config.url = "https://my-bucket.s3.amazonaws.com/sitemaps/sitemap.xml.gz"
  end
  process do |s|
    s.add('/', priority: 1.0, changefreq: "daily")
    s.add('/about', priority: 0.9, changefreq: "weekly")
  end
end
```

## CLI

You can use the CLI to generate the sitemap. The CLI will load the configuration file and run the sitemap generation.

```bash
bundle exec site_maps generate --config-file config/sitemap.rb
```

To enqueue dynamic processes, you can pass the process name with the context values.

```bash
bundle exec site_maps generate monthly_posts --config-file config/sitemap.rb --context=year:2021,month:1
```

## Notification

You can subscribe to the internal events to receive notifications about the sitemap generation. The following events are available:

* `sitemaps.runner.enqueue_process` - Triggered when a process is enqueued.
* `sitemaps.runner.before_process_execution` - Triggered before a process starts execution
* `sitemaps.runner.process_execution` - Triggered when a process finishes execution.
* `sitemaps.builder.finalize_urlset` - Triggered when the sitemap builder finishes the URL set.

You can subscribe to the events using the following code:

```ruby
SiteMaps::Notification.subscribe("sitemaps.runner.enqueue_process") do |event|
  puts "Enqueueing process #{event.payload[:name]}"
end
```

We have the standard event handler `SiteMaps::Runner::EventListener` that will print the events to the standard output. You can use it to view the progress of the sitemap generation.

```ruby
SiteMaps::Notification.subscribe(SiteMaps::Runner::EventListener)
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue_all
  .run
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/site_maps.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
