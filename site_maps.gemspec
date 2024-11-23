# frozen_string_literal: true

require_relative "lib/site_maps/version"

Gem::Specification.new do |spec|
  spec.name = "site_maps"
  spec.version = SiteMaps::VERSION
  spec.authors = ["Marcos G. Zimmermann"]
  spec.email = ["mgzmaster@gmail.com"]

  spec.summary = <<~SUMMARY
    Concurrent and Incremental sitemap.xml builder for ruby applications
  SUMMARY
  spec.description = <<~DESCRIPTION
    SiteMaps is a framework-agnostic library for building sitemap.xml files in a concurrent and incremental way.
  DESCRIPTION

  spec.homepage = "https://github.com/marcosgz/site_maps"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  raise "RubyGems 2.0 or newer is required to protect against public gem pushes." unless spec.respond_to?(:metadata)

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "https://github.com/marcosgz/site_maps/issues"
  spec.metadata["documentation_uri"] = "https://github.com/marcosgz/site_maps"
  spec.metadata["source_code_uri"] = "https://github.com/marcosgz/site_maps"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir = "exec"
  spec.executables = spec.files.grep(%r{^exec/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.0"
  spec.add_dependency "zeitwerk", ">= 0"
  spec.add_dependency "builder", "~> 3.0"
  spec.add_dependency "concurrent-ruby", ">= 1.1"
  spec.add_dependency "thor", ">= 0.0.0"
end
