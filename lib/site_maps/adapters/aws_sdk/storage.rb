# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::Storage
  attr_reader :config

  def initialize(config)
    @config = config
  end

  # def existing_sitemap_indexes
  #   objs = list_objects(prefix: config.remote_sitemap_directory)
  #   config.read_index_sitemaps.select do |item|
  #     objs.any? { |obj| item.relative_path == obj.key }
  #   end
  # end

  def upload(location, **options)
    options[:acl] ||= config.acl if config.acl
    options[:cache_control] ||= config.cache_control if config.cache_control
    options[:content_type] ||= location.gzip? ? "application/gzip" : "application/xml"
    lastmod = options.delete(:last_modified) || Time.now
    options[:metadata] ||= {}
    options[:metadata]["given-last-modified"] = lastmod.utc.strftime("%Y-%m-%dT%H:%M:%S%:z")
    obj = object(location.remote_path)
    obj.upload_file(location.path, **options)
  end

  def read(location)
    obj = object(location.remote_path).get
    [obj.body.read, {content_type: obj.content_type}]
  rescue Aws::S3::Errors::NoSuchKey
    raise SiteMaps::FileNotFoundError, "File not found: #{location.remote_path}"
  end

  def delete(location)
    object(location.remote_path).delete
  rescue Aws::S3::Errors::NoSuchKey
    raise SiteMaps::FileNotFoundError, "File not found: #{location.remote_path}"
  end

  private

  def list_objects(prefix:)
    config.s3_bucket.objects(
      prefix: prefix
    )
  end

  def object(remote_path)
    config.s3_bucket.object(remote_path)
  end
end
