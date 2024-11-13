# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Process do
  describe "#location" do
    it "returns the location" do
      process = described_class.new(:name, "/path/%{year}-%{month}", {}, nil)
      expect(process.location(year: 2020, month: "01")).to eq("/path/2020-01")
    end

    it "returns nil if there is no location" do
      process = described_class.new(:name, nil, {}, nil)
      expect(process.location(year: 2020, month: "01")).to be_nil
    end

    it "uses the kwargs_template" do
      process = described_class.new(:name, "/path/%{year}-%{month}", { year: 2020 }, nil)
      expect(process.location(month: "01")).to eq("/path/2020-01")
    end
  end

  describe "#static?" do
    it "returns true if there are no dynamic kwargs" do
      process = described_class.new(:name, "/path/%{year}-%{month}", {}, nil)
      expect(process).to be_static
    end

    it "returns false if there are dynamic kwargs" do
      process = described_class.new(:name, "/path/%{year}-%{month}", { year: 2020 }, nil)
      expect(process).not_to be_static
    end
  end

  describe "#dynamic?" do
    it "returns false if there are no dynamic kwargs" do
      process = described_class.new(:name, "/path/%{year}-%{month}", {}, nil)
      expect(process).not_to be_dynamic
    end
  end

  describe "#call" do
    let(:builder) do
      Class.new do
        attr_reader :urls

        def add(url)
          (@urls ||= []) << url
        end
      end.new
    end

    it "calls the block with the builder and the kwargs" do
      block = ->(builder, kwargs) { builder.add("/path/#{kwargs[:year]}") }
      process = described_class.new(:name, nil, { year: 2020 }, block)
      process.call(builder, month: "01")
      expect(builder.urls).to eq(["/path/2020"])
    end

    it "does nothing if there is no block" do
      process = described_class.new(:name, nil, {}, nil)
      process.call(builder)
      expect(builder.urls).to be_nil
    end
  end
end
