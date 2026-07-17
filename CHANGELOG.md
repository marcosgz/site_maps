# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.2 - 2026-07-17

### Added
- Middleware `aliases:` option: maps an incoming public request path to another public request path (applied before the prefix options), so the same content can be served at multiple locations without a redirect — e.g. `aliases: { "/sitemap.xml" => "/sitemap_index.xml" }`. Accepts a hash or a callable returning a hash.

## 0.1.1 - 2026-05-12

### Fixed
- AwsSdk adapter: switched from the deprecated `Aws::S3::Object#upload_file` to `Aws::S3::TransferManager#upload_file` to silence the deprecation warning and keep working past the next aws-sdk-s3 major.

## 0.0.1.beta1 - 2024-11-07
The first release of the gem
