# frozen_string_literal: true

class SiteMaps::Adapters::AwsSdk::Location < SiteMaps::Adapters::FileSystem::Location
  ROOT_RE = %r{^/}

  def remote_path
    make_relative(uri.path)
  end
end
