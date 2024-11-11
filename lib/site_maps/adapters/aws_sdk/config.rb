# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::Config < SiteMaps::Configuration
  attribute :access_key_id, default: -> { ENV["AWS_ACCESS_KEY_ID"] }
  attribute :secret_access_key, default: -> { ENV["AWS_SECRET_ACCESS_KEY"] }
  attribute :region, default: -> { ENV.fetch("AWS_REGION", "us-east-1") }
  attribute :bucket, default: -> { ENV["AWS_BUCKET"] }
  attribute :acl, default: "public-read"
  attribute :cache_control, default: "private, max-age=0, no-cache"

  attr_reader :aws_extra_options

  def initialize(**options)
    defined_attrs = options.slice(*self.class.attributes.keys)
    super(**defined_attrs)

    @aws_extra_options = options.reject { |k, v| defined_attrs.key?(k) }
  end

  def s3_resource
    @s3_resource ||= begin
      require "aws-sdk-s3"

      ::Aws::S3::Resource.new(s3_resource_options)
    end
  end

  def inspect
    "#<#{self.class}:#{object_id} access_key_id=#{access_key_id.inspect} region=#{region.inspect} bucket=#{bucket.inspect}>"
  end
  alias_method :to_s, :inspect

  private

  def s3_resource_options
    options = aws_extra_options.dup
    options[:region] = region if region?
    if access_key_id? && secret_access_key?
      options[:credentials] = ::Aws::Credentials.new(
        access_key_id,
        secret_access_key
      )
    end

    options
  end
end
