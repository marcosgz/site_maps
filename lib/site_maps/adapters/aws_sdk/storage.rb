# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::Storage
  attr_reader :config

  def initialize(config)
    @config = config
  end

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
    metadata = {
      content_type: obj.content_type
    }
    if (raw = obj.metadata["given-last-modified"]) &&
        (time = Time.parse(raw))
      metadata[:last_modified] = time
    end
    [obj.body.read, metadata]
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
