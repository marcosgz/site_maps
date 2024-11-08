# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Primitives::String do
  describe "#classify" do
    context "when dry-inflector is available" do
      before do
        stub_const("Dry::Inflector", Class.new { def classify(string); "Classified"; end })
      end

      it "returns the classified string" do
        expect(described_class.new("string").classify).to eq("Classified")
      end
    end

    context "when active-support is available" do
      before do
        stub_const("ActiveSupport::Inflector", Class.new { def self.classify(string); "Classified"; end })
      end

      it "returns the classified string" do
        expect(described_class.new("string").classify).to eq("Classified")
      end
    end

    context "when no inflector is available" do
      it "returns the classified string" do
        expect(described_class.new("my_string").classify).to eq("MyString")
      end
    end
  end
end
