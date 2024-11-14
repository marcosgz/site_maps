# frozen_string_literal: true

class SiteMaps::Adapters::FileSystem::Location < Struct.new(:root, :url)
  ROOT_RE = %r{^/}
  GZIP_RE = %r{\.gz$}

  def path
    File.join(
      root,
      make_relative(uri.path)
    )
  end

  def directory
    Pathname.new(root).join(remote_relative_dir).to_s
  end

  def gzip?
    GZIP_RE.match?(uri.path)
  end

  private

  def uri
    @uri ||= URI.parse(url)
  end

  def remote_relative_dir
    make_relative(File.dirname(uri.path))
  end

  def make_relative(path)
    path.sub(ROOT_RE, "")
  end
end
