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

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue_all
  .run
```

or you can use the CLI to generate the sitemap:

```bash
bundle exec site_maps generate --config-file config/sitemap.rb
```

### Configuration

Configuration can be defined using the `configure` block or by passing the configuration options to the `use` method. Each adapter may have specific configuration options, but the following options are common to all adapters:

* `url` - URL of the main sitemap index file. This URL must ends with `.xml` or `.xml.gz`.
* `directory` - Directory where the sitemap files will be stored.

Configuration using the `#configure` block

```ruby
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz"
    config.directory = "/home/www/public"
  end
  # define sitemap processes..
end
```

Configuration using `#config` method

```ruby
SiteMaps.use(:file_system) do
  config.url = "https://example.com/sitemaps/sitemap.xml.gz"
  config.directory = "/home/www/public"
  # define sitemap processes..
end
```

Configuration passing options to the `#use` method

```ruby
SiteMaps.use(:file_system, url: "https://example.com/sitemaps/sitemap.xml.gz", directory: "/home/www/public") do
  # define sitemap processes..
end
```

Refer to the adapter documentation to see the specific configuration options.

### Gzip Compression

The sitemap files can be automatically compressed using the gzip algorithm. To enable the gzip compression, just pass the sitemap url with the `.gz` extension.

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz" # Location of main sitemap index file
    config.directory = "/home/www/public"
  end
  process do |s|
    # Add sitemap links
  end
end
```

### Sitemap Index

For small websites, you can use a single sitemap file to store all the links. However, for large websites with thousands of links, you should use a sitemap index file to store the sitemap links. This library will automatically generate the sitemap index file if you define multiple processes or if the amount of links exceeds the maximum limit of links or file size.


Criteria to generate the sitemap index file:
* Multiple processes defined in the configuration file.
* The amount of links exceeds the maximum limit of links (50,000 links).
* The amount of news links exceeds the maximum limit of news links (1,000 links).
* The uncompressed file size exceeds the maximum limit of file size (50MB).

### Static and Dynamic Processes

Sitemap links are defined in the `process` block because the gem is designed to generate sitemaps for large websites in parallel. It means that each process will be executed in a separate thread, which will improve the performance of the sitemap generation.

Each process can have a unique name and a unique sitemap file location. By omitting the name and the file location, the process will use the `:default` value.

Bellow is an example of a configuration file with multiple processes:

```ruby
# config/sitemap.rb
SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml" # Location of main sitemap index file
    config.directory = "/home/www/public"
  end
  # Static Processes
  process do |s|
    s.add('/', priority: 1.0, changefreq: "daily")
    s.add('/about', priority: 0.9, changefreq: "weekly")
  end
  process :categories, "categories/sitemap.xml" do |s|
    Category.find_each do |category|
      s.add(category_path(category), priority: 0.7)
    end
  end
  # Dynamic Processes
  process :posts, "posts/%{year}-%{month}/sitemap.xml", year: Date.today.year, month: Date.today.month do |s, year:, month:|
    Post.where(year: year.to_i, month: month.to_i).find_each do |post|
      s.add(post_path(post), priority: 0.8)
    end
  end
end
```

Dynamic `process` are defined by passing a process name, a location, and a list of extra arguments that will be dinamically replaced by the given values in the `enqueue` method.

Location can contain placeholders that will be replaced by the values passed to the process block(The `%{year}` and `%{month}` of example bellow). Both relative and absolute paths are supported. Note that when using relative paths, the base dir of main sitemap index file will be used as the root directory.

It will let you enqueue the same process multiple times with different values.

```ruby
SiteMaps.generate(config_file: "config/sitemap.rb")
  .enqueue(:posts, year: "2021", month: "01")
  .enqueue(:posts, year: "2021", month: "02")
  .enqueue_remaining # Enqueue all remaining processes (default and categories)
  .run
```

**Important Considerations:**

* The values of the extra arguments may be strings when they are coming from the CLI or other sources.
* By omitting the extra arguments, the process will be enqueued with the default values defined in the configuration file. So make sure you define default values or properly add nil checks in the process block to avoid errors.

### Sitemap Extensions

The sitemap builder supports the following sitemap extensions:

* [Alternate](http://support.google.com/webmasters/bin/answer.py?hl=en&answer=2620865)
* [Image](https://support.google.com/webmasters/answer/178636?hl=en)
* [Mobile](http://support.google.com/webmasters/bin/answer.py?hl=en&answer=34648)
* [News](https://support.google.com/news/publisher-center/answer/9606710?hl=en)
* [PageMap](https://developers.google.com/custom-search/docs/structured_data?csw=1#pagemaps)
* [Video](https://support.google.com/webmasters/answer/80471?hl=en)

You can add the sitemap links with the extensions by passing a hash with the extension name as the key and the extension attributes as the value.

#### Image

Images can be added to the sitemap links by passing `images` attributes to the `add` method. The `images` attribute should be an array of hashes with the image attributes.

Check out the Google specification [here](https://support.google.com/webmasters/answer/178636?hl=en).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add(
      '/',
      priority: 1.0,
      changefreq: "daily",
      images: [
        { loc: "https://example.com/image.jpg" }
      ],
    )
  end
end
```

Supported attributes:
* `loc` - URL of the image.
* `caption` - Image caption.
* `geo_location` - Image geo location.
* `title` - Image title.
* `license` - Image license.

#### Video

Videos can be added to the sitemap links by passing `videos` attributes to the `add` method. The `videos` attribute should be an array of hashes with the video attributes.

Check out the Google specification [here](https://support.google.com/webmasters/answer/80471?hl=en).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add(
      '/',
      priority: 1.0,
      changefreq: "daily",
      videos: [
        {
          thumbnail_loc: "https://example.com/thumbnail.jpg",
          title: "Video Title",
          description: "Video Description",
          content_loc: "https://example.com/video.mp4",
          player_loc: "https://example.com/player.swf",
          allow_embed: "yes",
          autoplay: "ap=1",
          # ...
        }
      ],
    )
  end
end
```
Supported attributes:
* `thumbnail_loc` - URL of the thumbnail image.
* `title` - Title of the video.
* `description` - Description of the video.
* `content_loc` - URL of the video content.
* `player_loc` - URL of the video player.
* `allow_embed` - Allow embed attribute of the player location.
* `autoplay` - Autoplay attribute of the player location.
* `duration` - Duration of the video in seconds.
* `expiration_date` - Expiration date of the video.
* `rating` - Rating of the video.
* `view_count` - View count of the video.
* `publication_date` - Publication date of the video.
* `tags` - Tags of the video.
* `tag` - Single tag of the video.
* `category` - Category of the video.
* `family_friendly` - Family friendly attribute of the video.
* `gallery_loc` - URL of the video gallery.
* `gallery_title` - Title of the video gallery.
* `uploader` - Uploader of the video.
* `uploader_info` - Uploader info of the video.
* `price` - Price of the video.
* `price_currency` - Currency of the video price.
* `price_type` - Type of the video price.
* `price_resolution` - Resolution of the video price.
* `live` - Live attribute of the video.
* `requires_subscription` - Requires subscription attribute of the video.

#### PageMap

PageMap sitemaps can be added to the sitemap links by passing `pagemap` attributes to the `add` method. The `pagemap` attribute should be a hash with the pagemap attributes.

Check out the Google specification [here](https://developers.google.com/custom-search/docs/structured_data?csw=1#pagemaps).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add(
      '/',
      priority: 1.0,
      changefreq: "daily",
      pagemap: {
        dataobjects: [
          {
            type: "document",
            id: "1",
            attributes: [
              { name: "title", value: "Page Title" },
              { name: "description", value: "Page Description" },
              { name: "url", value: "https://example.com" },
            ]
          }
        ]
      }
    )
  end
end
```

Supported attributes:
* `dataobjects` - Array of hashes with the data objects.
    * `type` - Type of the object.
    * `id` - ID of the object.
    * `attributes` - Array of hashes with the attributes.
        * `name` - Name of the attribute.
        * `value` - Value of the attribute.

#### News

News sitemaps can be added to the sitemap links by passing `news` attributes to the `add` method. The `news` attribute should be a hash with the news attributes.

Check out the Google specification [here](https://support.google.com/news/publisher-center/answer/9606710?hl=en).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add(
      '/',
      priority: 1.0,
      changefreq: "daily",
      news: {
        publication_name: "Publication Name",
        publication_language: "en",
        publication_date: Time.now,
        genres: "PressRelease",
        access: "Subscription",
        title: "News Title",
        keywords: "News Keywords",
        stock_tickers: "NASDAQ:GOOG",
      }
    )
  end
end
```

Supported attributes:
* `publication_name` - Name of the publication.
* `publication_language` - Language of the publication.
* `publication_date` - Publication date of the news.
* `genres` - Genres of the news.
* `access` - Access of the news.
* `title` - Title of the news.
* `keywords` - Keywords of the news.
* `stock_tickers` - Stock tickers of the news.

#### Alternates

You can add alternate links to the sitemap links by passing `alternates` attributes to the `add` method. The `alternates` attribute should be an array of hashes with the alternate attributes.

Check out the Google specification [here](http://support.google.com/webmasters/bin/answer.py?hl=en&answer=2620865).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add(
      '/',
      priority: 1.0,
      changefreq: "daily",
      alternates: [
        { href: "https://example.com/en", lang: "en" },
        { href: "https://example.com/es", lang: "es" },
      ],
    )
  end
end
```

Supported attributes:
* `href` - URL of the alternate link. (Required)
* `lang` - Language of the alternate link. (Optional)
* `nofollow` - Nofollow attribute of the alternate link. (Optional)
* `media` - Media targets for responsive design pages. (Optional)

#### Mobile

Mobile sitemaps include a specific <mobile:mobile/> tag.

Check out the Google specification [here](http://support.google.com/webmasters/bin/answer.py?hl=en&answer=34648).

```ruby
config = { ... }
SiteMaps.use(:file_system, **config) do
  process do |s|
    s.add('/', mobile: true)
  end
end
```

Supported attributes:

* `mobile` - Mobile attribute of the sitemap link.

## Adapters

The gem provides adapters to store the sitemaps in different locations. The following adapters are available:

* File System
* AWS S3

### File System

You can use the file system adapter to store the sitemaps in the file system. The configuration is simple, you just need to provide the directory where the sitemaps will be stored.

```ruby

SiteMaps.use(:file_system) do
  configure do |config|
    config.url = "https://example.com/sitemaps/sitemap.xml.gz"
    config.directory = "/home/www/public"
  end
  process do |s|
    # Add sitemap links
  end
end
```

### AWS S3

You can use the AWS S3 adapter to store the sitemaps in an S3 bucket. The configuration is similar to the file system adapter, but you need to provide the AWS SDK options.

```ruby
SiteMaps.use(:aws_sdk) do
  configure do |config|
    config.url = "https://my-bucket.s3.amazonaws.com/sitemaps/sitemap.xml"
    config.directory = "/tmp" # Local directory to store the sitemaps before uploading to S3
    # AWS S3 specific options
    config.bucket = "my-bucket"
    config.region = "us-east-1"
    config.aws_access_key = ENV["AWS_ACCESS_KEY_ID"]
    config.aws_secret_key = ENV["AWS_SECRET_ACCESS_KEY"]
    # Optional parameters (default values)
    config.acl = "public-read"
    config.cache_control = "private, max-age=0, no-cache"
  end
  process do |s|
    # Add sitemap links
  end
end
```

If you want to let your rails application as a proxy to the sitemap files, you can create a controller to serve the sitemap files from the S3 bucket.

```ruby
# config/routes.rb
get "sitemaps/*relative_path", to: "sitemaps#show", as: :sitemap
```

```ruby
# app/controllers/sitemaps_controller.rb
class SitemapsController < ApplicationController
  def show
    location = params.permit("relative_path", "format").to_h.values.join(".")

    unless location =~ /\.xml(\.gz)?$/ # You may want add more validations here
      raise ActionController::RoutingError, "Not found"
    end

    data, meta = SiteMaps.current_adapter.read(File.join("sitemaps", location))
    if location.ends_with?(".xml")
      render xml: data
    else
      send_data(data, disposition: "attachment", type: meta[:content_type])
    end
  rescue SiteMaps::FileNotFoundError
    raise ActionController::RoutingError, "Not found"
  end
end
```

Make sure to let sitemap config in the initializer. You may want to add some caching to avoid hitting the S3 bucket on every request.


### Custom Adapters

You can create custom adapters to store the sitemaps in different locations. You just need to create a class that implements the `SiteMaps::Adapters::Adapter` interface. The adapter should implement the following methods:

* `write(url, raw_data, **extra)` - Write the sitemap data to the storage.
* `read(url)` - Read the sitemap data from the storage.
* `delete(url)` - Delete the sitemap data from the storage.

```ruby
class MyAdapter < SiteMaps::Adapters::Adapter
  def write(url, raw_data, **extra)
    # Write the sitemap data to the storage
  end

  def read(url)
    # Read the sitemap data from the storage
  end

  def delete(url)
    # Delete the sitemap data from the storage
  end
end

SiteMaps.use(MyAdapter, **config) do
  process do |s|
    # Add sitemap links
  end
end
```

#### Adapter Configuration

If you adapter requires additional configuration, you can define a `<adapter class>::Config` inheriting from `SiteMaps::Configuration` and implement the required configuration options.

```ruby
class MyAdapter::Config < SiteMaps::Configuration
  attribute :api_key, default: -> { ENV["MY_API_KEY"] }
end
```

During the adapter initialization, it will automatically detect the configuration class and use it to load the configuration options.

```ruby
SiteMaps.use(MyAdapter) do
  configure do |config|
    # ...
    config.api_key = "my-api-key"
  end
  process do |s|
    # Add sitemap links
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
bundle exec site_maps generate monthly_posts \
  --config-file config/sitemap.rb \
  --context=year:2021 month:1
```

Enqueue dynamic + remaining processes

```bash
bundle exec site_maps generate monthly_posts \
  --config-file config/sitemap.rb \
  --context=year:2021 month:1 \
  --enqueue-remaining
```

passing max threads to run the processes in parallel

```bash
bundle exec site_maps generate \
  --config-file config/sitemap.rb \
  --max-threads 10
```

## Notification

You can subscribe to the internal events to receive notifications about the sitemap generation. The following events are available:

* `sitemaps.enqueue_process` - Triggered when a process is enqueued.
* `sitemaps.before_process_execution` - Triggered before a process starts execution
* `sitemaps.process_execution` - Triggered when a process finishes execution.
* `sitemaps.finalize_urlset` - Triggered when the sitemap builder finishes the URL set.

You can subscribe to the events using the following code:

```ruby
SiteMaps::Notification.subscribe("sitemaps.enqueue_process") do |event|
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

## Mixins

You can use mixins to extend the sitemap builder with additional methods. The mixins can be used to define common methods that will be used in multiple processes. Make sure they are thread-safe, otherwise I recommend to define them in the process block.

```ruby
module MyMixin
  def repository
    Repository.new
  end

  def post_path(post)
    "/posts/#{post.slug}"
  end
end

SiteMaps.use(:file_system) do
  include_module(MyMixin)
  process do |s|
    repository.posts.each do |post|
      s.add(post_path(post), priority: 0.8)
    end
  end
end
```

We already have a built-in mixin for Rails applications that provides the url helpers through the `route` method.

```ruby
SiteMaps.use(:file_system) do
  include_module(SiteMaps::Mixins::Rails)
  process do |s|
    s.add(route.root_path, priority: 1.0)
    s.add(route.about_path, priority: 0.9)
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/site_maps.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
