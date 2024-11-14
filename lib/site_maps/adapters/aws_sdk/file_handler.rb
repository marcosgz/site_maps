# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::FileHandler
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def existing_sitemap_indexes
    objs = list_objects(prefix: config.remote_sitemap_directory)

    config.read_index_sitemaps.select do |item|
      objs.any? { |obj| item.relative_path == obj.key }
    end
  end

  def write(location, raw_data)
  end

  def read(remote_path)
    obj = object(remote_path).get
    [obj.body.read, {content_type: obj.content_type}]
  rescue Aws::S3::Errors::NoSuchKey
    # raise FileNotFoundError, "Sitemap file not found: #{remote_path}"
  end

  def delete(remote_path)
    object(remote_path).delete
  rescue Aws::S3::Errors::NoSuchKey
    # raise FileNotFoundError, "Sitemap file not found: #{remote_path}"
  end

  private

  def list_objects(prefix:)
    config.s3_resource.bucket(config.bucket).objects(
      prefix: prefix
    )
  end

  def object(remote_path)
    config.s3_resource.bucket(config.bucket).object(remote_path)
  end
end
