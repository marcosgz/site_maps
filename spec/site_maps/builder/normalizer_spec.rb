# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Builder::Normalizer do
  describe ".w3c_date" do
    it "converts dates and times to W3C format" do
      expect(described_class.w3c_date(Date.new(0))).to eq("0000-01-01")
      expect(described_class.w3c_date(Time.at(0).utc)).to eq("1970-01-01T00:00:00+00:00")
      expect(described_class.w3c_date(DateTime.new(0))).to eq("0000-01-01T00:00:00+00:00")
    end

    it "returns strings unmodified" do
      expect(described_class.w3c_date("2010-01-01")).to eq("2010-01-01")
    end

    it "tries to convert to utc" do
      time = Time.at(0)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(time).to receive(:respond_to?).and_return(true)
      expect(described_class.w3c_date(time)).to eq("1970-01-01T00:00:00+00:00")
    end

    it "includes timezone for objects which do not respond to iso8601 or utc" do
      time = Time.at(0)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(time).to receive(:respond_to?).and_return(false)
      expect(described_class.w3c_date(time)).to eq(time.strftime("%Y-%m-%dT%H:%M:%S%:z"))
    end

    it "supports integers" do
      expect(described_class.w3c_date(Time.at(0).to_i)).to eq("1970-01-01T00:00:00+00:00")
    end

    it "supports DateTime" do
      expect(described_class.w3c_date(DateTime.new(0))).to eq("0000-01-01T00:00:00+00:00")
    end
  end

  describe ".yes_or_no" do
    it "returns yes for truthy values" do
      expect(described_class.yes_or_no(true)).to eq("yes")
      expect(described_class.yes_or_no("yes")).to eq("yes")
      expect(described_class.yes_or_no("YES")).to eq("yes")
    end

    it "returns no for falsey values" do
      expect(described_class.yes_or_no(false)).to eq("no")
      expect(described_class.yes_or_no("no")).to eq("no")
      expect(described_class.yes_or_no("NO")).to eq("no")
    end
  end

  describe ".yes_or_no_with_default" do
    it "returns yes for truthy values" do
      expect(described_class.yes_or_no_with_default(true, false)).to eq("yes")
      expect(described_class.yes_or_no_with_default("yes", "no")).to eq("yes")
      expect(described_class.yes_or_no_with_default("YES", "no")).to eq("yes")
    end

    it "returns no for falsey values" do
      expect(described_class.yes_or_no_with_default(false, true)).to eq("no")
      expect(described_class.yes_or_no_with_default("no", "yes")).to eq("no")
      expect(described_class.yes_or_no_with_default("NO", "yes")).to eq("no")
    end

    it "returns default for nil values" do
      expect(described_class.yes_or_no_with_default(nil, true)).to eq("yes")
      expect(described_class.yes_or_no_with_default(nil, false)).to eq("no")
    end
  end

  describe ".format_float" do
    it "returns formatted float" do
      expect(described_class.format_float(0.499999)).to eq("0.5")
      expect(described_class.format_float(3.444444)).to eq("3.4")
      expect(described_class.format_float("0.5")).to eq("0.5")
    end
  end
end
