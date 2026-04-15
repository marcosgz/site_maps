# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::URL do
  let(:link) { "http://example.com/posts.html" }
  let(:attributes) { {} }
  let(:instance) { described_class.new(link, **attributes) }

  describe "#initialize" do
    it "sets default attributes" do
      expect(instance.attributes).to eq(
        loc: link,
        changefreq: "weekly",
        priority: 0.5,
        alternates: [],
        videos: [],
        images: []
      )
    end

    it "wraps alternates" do
      attributes[:alternates] = {href: "http://example.com/posts.html"}
      expect(instance.attributes[:alternates]).to contain_exactly(attributes[:alternates])
    end

    it "wraps videos" do
      attributes[:videos] = {thumbnail_loc: "http://example.com/posts.jpg"}
      expect(instance.attributes[:videos]).to contain_exactly(attributes[:videos])
    end

    it "wraps images" do
      attributes[:images] = {loc: "http://example.com/posts.jpg"}
      expect(instance.attributes[:images]).to contain_exactly(attributes[:images])
    end

    it "wraps video" do
      attributes[:video] = {thumbnail_loc: "http://example.com/posts.jpg"}
      expect(instance.attributes[:videos]).to contain_exactly(attributes[:video])
    end

    it "wraps alternate" do
      attributes[:alternate] = {href: "http://example.com/posts.html"}
      expect(instance.attributes[:alternates]).to contain_exactly(attributes[:alternate])
    end

    it "wraps image" do
      attributes[:image] = {loc: "http://example.com/posts.jpg"}
      expect(instance.attributes[:images]).to contain_exactly(attributes[:image])
    end
  end

  describe "#[]" do
    it "returns attribute" do
      expect(instance[:changefreq]).to eq("weekly")
    end
  end

  describe "#to_xml" do
    let(:doc) do
      Nokogiri::XML([
        SiteMaps::Builder::URLSet::HEADER,
        instance.to_xml,
        SiteMaps::Builder::URLSet::FOOTER
      ].join("\n"))
    end

    context "with default attributes" do
      it "returns url with link" do
        expect(doc.css("url loc").text).to eq(link)
      end

      it "returns url with changefreq" do
        expect(doc.css("url changefreq").text).to eq("weekly")
      end

      it "returns url with priority" do
        expect(doc.css("url priority").text).to eq("0.5")
      end

      it "returns url without lastmod" do
        expect(doc.css("url lastmod")).to be_empty
      end

      it "returns url without expires" do
        expect(doc.css("url expires")).to be_empty
      end
    end

    context "with lastmod" do
      let(:time) { Time.at(0) }
      let(:attributes) { {lastmod: time} }

      it "returns url with lastmod" do
        expect(doc.css("url lastmod").text).to eq(time.strftime("%Y-%m-%dT%H:%M:%S%:z"))
      end
    end

    context "with expires" do
      let(:time) { Time.at(0) }
      let(:attributes) { {expires: time} }

      it "returns url with expires" do
        expect(doc.css("url expires").text).to eq(time.strftime("%Y-%m-%dT%H:%M:%S%:z"))
      end
    end

    context "with news" do
      let(:attributes) { {news: {publication_name: "Example", publication_date: "2010-01-01"}} }

      it "returns url with news" do
        expect(doc.css("url news|news news|publication news|name").text).to eq("Example")
        expect(doc.css("url news|news news|publication_date").text).to eq("2010-01-01")
      end
    end
  end

  describe "emit_priority and emit_changefreq" do
    context "when emit_priority is false" do
      let(:instance) { described_class.new(link, emit_priority: false) }

      it "does not include priority in attributes" do
        expect(instance.attributes).not_to have_key(:priority)
      end

      it "does not emit priority in XML" do
        doc = Nokogiri::XML([
          SiteMaps::Builder::URLSet::HEADER,
          instance.to_xml,
          SiteMaps::Builder::URLSet::FOOTER
        ].join("\n"))

        expect(doc.css("url priority")).to be_empty
      end
    end

    context "when emit_changefreq is false" do
      let(:instance) { described_class.new(link, emit_changefreq: false) }

      it "does not include changefreq in attributes" do
        expect(instance.attributes).not_to have_key(:changefreq)
      end

      it "does not emit changefreq in XML" do
        doc = Nokogiri::XML([
          SiteMaps::Builder::URLSet::HEADER,
          instance.to_xml,
          SiteMaps::Builder::URLSet::FOOTER
        ].join("\n"))

        expect(doc.css("url changefreq")).to be_empty
      end
    end

    context "when both are false" do
      let(:instance) { described_class.new(link, emit_priority: false, emit_changefreq: false) }

      it "still includes loc" do
        doc = Nokogiri::XML([
          SiteMaps::Builder::URLSet::HEADER,
          instance.to_xml,
          SiteMaps::Builder::URLSet::FOOTER
        ].join("\n"))

        expect(doc.css("url loc").text).to eq(link)
        expect(doc.css("url priority")).to be_empty
        expect(doc.css("url changefreq")).to be_empty
      end
    end

    context "when explicitly passed even with emit flags off" do
      let(:instance) { described_class.new(link, emit_priority: false, emit_changefreq: false, priority: 0.9, changefreq: "daily") }

      it "still emits explicitly provided values" do
        doc = Nokogiri::XML([
          SiteMaps::Builder::URLSet::HEADER,
          instance.to_xml,
          SiteMaps::Builder::URLSet::FOOTER
        ].join("\n"))

        expect(doc.css("url priority").text).to eq("0.9")
        expect(doc.css("url changefreq").text).to eq("daily")
      end
    end
  end

  describe "#last_modified" do
    it "returns last modified date" do
      time = Time.new(2021, 1, 1)
      attributes[:lastmod] = time

      expect(instance.last_modified).to eq(time)
    end

    it "returns nil if last modified date is not set" do
      expect(instance.last_modified).to be_nil
    end
  end
end
