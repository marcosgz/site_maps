# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Sitemap::URL do
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

  describe "#w3c_date" do
    it "converts dates and times to W3C format" do
      expect(instance.send(:w3c_date, Date.new(0))).to eq("0000-01-01")
      expect(instance.send(:w3c_date, Time.at(0).utc)).to eq("1970-01-01T00:00:00+00:00")
      expect(instance.send(:w3c_date, DateTime.new(0))).to eq("0000-01-01T00:00:00+00:00")
    end

    it "returns strings unmodified" do
      expect(instance.send(:w3c_date, "2010-01-01")).to eq("2010-01-01")
    end

    it "tries to convert to utc" do
      time = Time.at(0)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(time).to receive(:respond_to?).and_return(true)
      expect(instance.send(:w3c_date, time)).to eq("1970-01-01T00:00:00+00:00")
    end

    it "includes timezone for objects which do not respond to iso8601 or utc" do
      time = Time.at(0)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(instance.send(:w3c_date, time)).to eq(time.strftime("%Y-%m-%dT%H:%M:%S%:z"))
    end

    it "supports integers" do
      expect(instance.send(:w3c_date, Time.at(0).to_i)).to eq("1970-01-01T00:00:00+00:00")
    end

    it "supports DateTime" do
      expect(instance.send(:w3c_date, DateTime.new(0))).to eq("0000-01-01T00:00:00+00:00")
    end
  end

  describe "#yes_or_no" do
    it "returns yes for truthy values" do
      expect(instance.send(:yes_or_no, true)).to eq("yes")
      expect(instance.send(:yes_or_no, "yes")).to eq("yes")
      expect(instance.send(:yes_or_no, "YES")).to eq("yes")
    end

    it "returns no for falsey values" do
      expect(instance.send(:yes_or_no, false)).to eq("no")
      expect(instance.send(:yes_or_no, "no")).to eq("no")
      expect(instance.send(:yes_or_no, "NO")).to eq("no")
    end
  end

  describe "#yes_or_no_with_default" do
    it "returns yes for truthy values" do
      expect(instance.send(:yes_or_no_with_default, true, false)).to eq("yes")
      expect(instance.send(:yes_or_no_with_default, "yes", "no")).to eq("yes")
      expect(instance.send(:yes_or_no_with_default, "YES", "no")).to eq("yes")
    end

    it "returns no for falsey values" do
      expect(instance.send(:yes_or_no_with_default, false, true)).to eq("no")
      expect(instance.send(:yes_or_no_with_default, "no", "yes")).to eq("no")
      expect(instance.send(:yes_or_no_with_default, "NO", "yes")).to eq("no")
    end

    it "returns default for nil values" do
      expect(instance.send(:yes_or_no_with_default, nil, true)).to eq("yes")
      expect(instance.send(:yes_or_no_with_default, nil, false)).to eq("no")
    end
  end

  describe "#format_float" do
    it "returns formatted float" do
      expect(instance.send(:format_float, 0.499999)).to eq("0.5")
      expect(instance.send(:format_float, 3.444444)).to eq("3.4")
      expect(instance.send(:format_float, "0.5")).to eq("0.5")
    end
  end

  describe "#to_xml" do
    let(:doc) do
      Nokogiri::XML([
        SiteMaps::Sitemap::URLSet::HEADER,
        instance.to_xml,
        SiteMaps::Sitemap::URLSet::FOOTER
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
end
