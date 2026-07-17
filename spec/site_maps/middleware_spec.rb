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

    context "with public_prefix (sitemaps stored at root, served under a longer public path)" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:middleware) do
        dir = fixtures_dir
        described_class.new(inner_app, public_prefix: "/sitemaps/example", adapter: SiteMaps.use(:file_system) {
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
    end

    context "with storage_prefix (sitemaps stored under a path, served at a shorter public URL)" do
      let(:storage_adapter) do
        SiteMaps.use(:noop) { config.url = "https://example.com/sitemaps/example/sitemap.xml" }
      end
      let(:middleware) do
        described_class.new(inner_app, storage_prefix: "/sitemaps/example", adapter: storage_adapter)
      end

      before do
        allow(storage_adapter).to receive(:read).and_return(["<urlset/>", {}])
      end

      it "serves sitemaps at the public root path" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, headers, _body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
        expect(storage_adapter).to have_received(:read).with("https://example.com/sitemaps/example/sitemap.xml")
      end

      it "rewrites <loc> URLs in the served XML to strip the storage prefix" do
        index_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <sitemapindex>
            <sitemap><loc>https://example.com/sitemaps/example/static/sitemap.xml</loc></sitemap>
            <sitemap><loc>https://example.com/sitemaps/example/posts/sitemap.xml</loc></sitemap>
          </sitemapindex>
        XML
        allow(storage_adapter).to receive(:read).and_return([index_xml, {}])

        env = {"PATH_INFO" => "/sitemap_index.xml", "REQUEST_METHOD" => "GET"}
        _status, _headers, body = middleware.call(env)

        expect(body.first).to include("<loc>https://example.com/static/sitemap.xml</loc>")
        expect(body.first).to include("<loc>https://example.com/posts/sitemap.xml</loc>")
        expect(body.first).not_to include("/sitemaps/example/")
      end
    end

    context "with public_prefix loc rewriting" do
      let(:pub_adapter) do
        SiteMaps.use(:noop) { config.url = "https://example.com/sitemap.xml" }
      end
      let(:middleware) do
        described_class.new(inner_app, public_prefix: "/sitemaps/example", adapter: pub_adapter)
      end

      it "rewrites <loc> URLs in sitemap index to add the public prefix" do
        index_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <sitemapindex>
            <sitemap><loc>https://example.com/static/sitemap.xml</loc></sitemap>
            <sitemap><loc>https://example.com/posts/sitemap.xml</loc></sitemap>
          </sitemapindex>
        XML
        allow(pub_adapter).to receive(:read).and_return([index_xml, {}])

        env = {"PATH_INFO" => "/sitemaps/example/sitemap_index.xml", "REQUEST_METHOD" => "GET"}
        _status, _headers, body = middleware.call(env)

        expect(body.first).to include("<loc>https://example.com/sitemaps/example/static/sitemap.xml</loc>")
        expect(body.first).to include("<loc>https://example.com/sitemaps/example/posts/sitemap.xml</loc>")
      end

      it "does not rewrite <loc> URLs in URL set files" do
        urlset_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset>
            <url><loc>https://example.com/some-page</loc></url>
          </urlset>
        XML
        allow(pub_adapter).to receive(:read).and_return([urlset_xml, {}])

        env = {"PATH_INFO" => "/sitemaps/example/sitemap.xml", "REQUEST_METHOD" => "GET"}
        _status, _headers, body = middleware.call(env)

        expect(body.first).to include("<loc>https://example.com/some-page</loc>")
        expect(body.first).not_to include("/sitemaps/example/some-page")
      end
    end

    context "with a callable public_prefix" do
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
          public_prefix: ->(env) { "/sitemaps/#{env["HTTP_HOST"]}" })
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

    context "with aliases" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:adapter) do
        dir = fixtures_dir
        SiteMaps.use(:file_system) do
          config.url = "https://example.com/sitemap.xml"
          config.directory = dir
        end
      end
      let(:middleware) do
        described_class.new(inner_app, adapter: adapter,
          aliases: {"/sitemap.xml" => "/sitemap_index.xml"})
      end

      it "serves the alias target's content at the alias path" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(headers["content-type"]).to eq("text/xml; charset=UTF-8")
        expect(body.first).to include("<sitemapindex")
      end

      it "serves identical content at the alias path and the target path" do
        _status, _headers, aliased = middleware.call({"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"})
        _status, _headers, direct = middleware.call({"PATH_INFO" => "/sitemap_index.xml", "REQUEST_METHOD" => "GET"})

        expect(aliased.first).to eq(direct.first)
      end

      it "passes through paths that are not aliased" do
        env = {"PATH_INFO" => "/about", "REQUEST_METHOD" => "GET"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq(["Not Found"])
      end
    end

    context "with a callable aliases map" do
      let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
      let(:adapter) do
        dir = fixtures_dir
        SiteMaps.use(:file_system) do
          config.url = "https://example.com/sitemap.xml"
          config.directory = dir
        end
      end
      let(:middleware) do
        described_class.new(inner_app, adapter: adapter,
          aliases: -> { {"/sitemap.xml" => "/sitemap_index.xml"} })
      end

      it "resolves the alias map per request" do
        env = {"PATH_INFO" => "/sitemap.xml", "REQUEST_METHOD" => "GET"}
        status, _headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(body.first).to include("<sitemapindex")
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
