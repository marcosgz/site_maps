module Fixtures
  def fixture_path(*path)
    File.join(fixture_root, *path)
  end

  def fixture_file(*path)
    File.open(fixture_path(*path))
  end

  def fixture_root
    File.expand_path("../fixtures", __dir__)
  end
end

RSpec.configure do |config|
  config.include Fixtures
end
