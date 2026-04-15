# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Middleware do
  let(:inner_app) { ->(env) { [404, {"content-type" => "text/plain"}, ["Not Found"]] } }
  let(:adapter) do
    SiteMaps.use(:noop) do
      config.url = "https://example.com/sitemap.xml"
    end
  end
  let(:middleware) { described_class.new(inner_app, adapter: adapter) }

  describe "#call" do
    context "when requesting an XSL stylesheet" do
      it "serves the urlset XSL" do
        env = {"PATH_INFO" => "/_sitemap-stylesheet.xsl", "REQUEST_METHOD" => "GET"}
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xsl; charset=UTF-8")
        expect(body.first).to include("urlset")
      end

      it "serves the index XSL" do
        env = {"PATH_INFO" => "/_sitemap-index-stylesheet.xsl", "REQUEST_METHOD" => "GET"}
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xsl; charset=UTF-8")
        expect(body.first).to include("sitemapindex")
      end
    end

    context "when requesting a sitemap" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:adapter) do
        dir = fixtures_dir
        SiteMaps.use(:file_system) do
          config.url = "https://example.com/sitemap.xml"
          config.directory = dir
        end
      end

      it "serves the sitemap with correct headers" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
        expect(headers["x-robots-tag"]).to eq("noindex, follow")
        expect(headers["cache-control"]).to eq("public, max-age=3600")
      end

      it "serves gzip sitemaps as decompressed XML" do
        env = {"PATH_INFO" => "/sitemap.xml.gz", "REQUEST_METHOD" => "GET"}
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
        expect(body.first).to include("<?xml")
      end

      it "passes through when sitemap is not found" do
        env = {"PATH_INFO" => "/missing.xml", "REQUEST_METHOD" => "GET"}
        status, _headers, _body = middleware.call(env)

        expect(status).to eq(404)
      end
    end

    context "when requesting a non-sitemap path" do
      it "passes through to the inner app" do
        env = {"PATH_INFO" => "/about", "REQUEST_METHOD" => "GET"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq(["Not Found"])
      end
    end

    context "with URL normalization redirects" do
      it "redirects sitemap0.xml to sitemap.xml with 301" do
        env = {"PATH_INFO" => "/sitemap0.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(301)
        expect(headers["location"]).to eq("/sitemap.xml")
      end

      it "redirects sitemap1.xml to sitemap.xml with 301" do
        env = {"PATH_INFO" => "/sitemap1.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(301)
        expect(headers["location"]).to eq("/sitemap.xml")
      end

      it "redirects posts0.xml.gz to posts.xml.gz" do
        env = {"PATH_INFO" => "/posts0.xml.gz", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(301)
        expect(headers["location"]).to eq("/posts.xml.gz")
      end

      it "does not redirect sitemap2.xml" do
        allow(adapter).to receive(:read).and_raise(SiteMaps::FileNotFoundError)

        env = {"PATH_INFO" => "/sitemap2.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(404)
        expect(headers).not_to include("location")
      end

      it "does not redirect the base sitemap.xml" do
        allow(adapter).to receive(:read).and_return(["<xml/>", {content_type: "application/xml"}])

        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers).not_to include("location")
      end
    end

    context "with a callable adapter" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:middleware) do
        dir = fixtures_dir
        described_class.new(inner_app, adapter: ->(env) {
          SiteMaps.use(:file_system) do
            config.url = "https://#{env["HTTP_HOST"]}/sitemap.xml"
            config.directory = dir
          end
        })
      end

      it "resolves the adapter per request for XSL" do
        env = {"PATH_INFO" => "/_sitemap-stylesheet.xsl", "REQUEST_METHOD" => "GET", "HTTP_HOST" => "tenant.com"}
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xsl; charset=UTF-8")
        expect(body.first).to include("urlset")
      end

      it "resolves the adapter per request for sitemaps" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET", "HTTP_HOST" => "tenant.com"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
      end

      it "passes through when the callable returns nil" do
        middleware = described_class.new(inner_app, adapter: ->(_env) {})
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq(["Not Found"])
      end
    end

    context "with a static path_prefix" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:middleware) do
        dir = fixtures_dir
        described_class.new(inner_app, path_prefix: "/sitemaps/example", adapter: SiteMaps.use(:file_system) {
          config.url = "https://example.com/sitemap.xml"
          config.directory = dir
        })
      end

      it "serves sitemaps under the prefixed path" do
        env = {"PATH_INFO" => "/sitemaps/example/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
      end

      it "passes through requests that don't match the prefix" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq(["Not Found"])
      end

      it "includes prefix in redirect location" do
        env = {"PATH_INFO" => "/sitemaps/example/sitemap0.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(301)
        expect(headers["location"]).to eq("/sitemaps/example/sitemap.xml")
      end
    end

    context "with a callable path_prefix" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:middleware) do
        dir = fixtures_dir
        described_class.new(inner_app,
          adapter: ->(env) {
            SiteMaps.use(:file_system) do
              config.url = "https://#{env["HTTP_HOST"]}/sitemap.xml"
              config.directory = dir
            end
          },
          path_prefix: ->(env) { "/sitemaps/#{env["HTTP_HOST"]}" })
      end

      it "resolves prefix per request" do
        env = {"PATH_INFO" => "/sitemaps/tenant.com/sitemap.xml", "REQUEST_METHOD" => "GET", "HTTP_HOST" => "tenant.com"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
      end

      it "passes through when path does not match resolved prefix" do
        env = {"PATH_INFO" => "/sitemaps/other.com/sitemap.xml", "REQUEST_METHOD" => "GET", "HTTP_HOST" => "tenant.com"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq(["Not Found"])
      end
    end

    context "with custom headers" do
      let(:middleware) do
        described_class.new(inner_app, adapter: adapter, x_robots_tag: "noindex", cache_control: "private")
      end

      it "uses custom header values for XSL responses" do
        env = {"PATH_INFO" => "/_sitemap-stylesheet.xsl", "REQUEST_METHOD" => "GET"}
        _status, headers, _body = middleware.call(env)

        expect(headers["cache-control"]).to eq("private")
      end
    end
  end
end
