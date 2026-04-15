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
