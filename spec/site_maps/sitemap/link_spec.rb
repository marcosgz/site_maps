# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Sitemap::Link do
  describe "#initialize" do
    subject(:link) do
      described_class.new("http://example.com", "/path", foo: :bar)
    end

    it "has a uri" do
      expect(link.uri).to be_a(URI)
    end

    it "has a uri with a path" do
      expect(link.uri.path).to eq("/path")
    end

    it "has a uri with a query" do
      expect(link.uri.query).to eq("foo=bar")
    end
  end

  describe "#to_s" do
    subject(:link) do
      described_class.new("http://example.com", "/path", foo: :bar)
    end

    it "returns the uri as a string" do
      expect(link.to_s).to eq("http://example.com/path?foo=bar")
    end
  end

  describe "#eql?" do
    subject(:link) do
      described_class.new("http://example.com", "/path", foo: :bar)
    end

    it "is equal to another link with the same uri" do
      other = described_class.new("http://example.com", "/path", foo: :bar)
      expect(link).to eq(other)
    end

    it "is not equal to another link with a different uri" do
      other = described_class.new("http://example.com", "/other", foo: :bar)
      expect(link).not_to eq(other)
    end
  end

  describe "#hash" do
    subject(:link) do
      described_class.new("http://example.com", "/path", foo: :bar)
    end

    it "is the same for two links with the same uri" do
      other = described_class.new("http://example.com", "/path", foo: :bar)
      expect(link.hash).to eq(other.hash)
    end

    it "is different for two links with a different uri" do
      other = described_class.new("http://example.com", "/other", foo: :bar)
      expect(link.hash).not_to eq(other.hash)
    end
  end
end
