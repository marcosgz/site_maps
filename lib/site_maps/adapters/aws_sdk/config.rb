# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::Config < SiteMaps::Configuration
  attribute :access_key_id
  attribute :secret_access_key
  attribute :region, default: "us-east-1"
  attribute :bucket
  attribute :acl, default: "public-read"
  attribute :cache_control, default: "private, max-age=0, no-cache"

  attr_reader :aws_extra_options

  def initialize(**options)
    defined_attrs = options.slice(*self.class.attributes.keys)
    super(**defined_attrs)

    @aws_extra_options = options.reject { |k, v| defined_attrs.key?(k) }
  end
end
