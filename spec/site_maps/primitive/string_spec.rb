# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::Primitive::String do
  after do
    described_class.remove_instance_variable(:@inflector)
  rescue NameError
  end

  describe ".inflector" do
    subject { described_class.inflector }

    before do
      described_class.remove_instance_variable(:@inflector)
    rescue NameError
    end

    context "when ActiveSupport::Inflector is available" do
      before do
        stub_const("ActiveSupport::Inflector", Class.new)

        if defined?(Dry::Inflector)
          @before_dry_inflector = Dry::Inflector
          Dry.send(:remove_const, :Inflector)
        end
      end

      after do
        if @before_dry_inflector
          Dry.const_set(:Inflector, @before_dry_inflector)
        end
      end

      it { is_expected.to eq(ActiveSupport::Inflector) }
    end

    context "when Dry::Inflector is available" do
      before do
        stub_const("Dry::Inflector", Class.new)

        if defined?(ActiveSupport::Inflector)
          @before_active_support_inflector = ActiveSupport::Inflector
          ActiveSupport.send(:remove_const, :Inflector)
        end
      end

      after do
        if @before_active_support_inflector
          ActiveSupport.const_set(:Inflector, @before_active_support_inflector)
        end
      end

      it { is_expected.to be_a(Dry::Inflector) }
    end

    context "when no inflector is available" do
      before do
        if defined?(ActiveSupport::Inflector)
          @before_active_support_inflector = ActiveSupport::Inflector
          ActiveSupport.send(:remove_const, :Inflector)
        end
        if defined?(Dry::Inflector)
          @before_dry_inflector = Dry::Inflector
          Dry.send(:remove_const, :Inflector)
        end
      end

      after do
        if @before_active_support_inflector
          ActiveSupport.const_set(:Inflector, @before_active_support_inflector)
        end
        if @before_dry_inflector
          Dry.const_set(:Inflector, @before_dry_inflector)
        end
      end

      it { is_expected.to be_nil }
    end
  end

  describe "#classify" do
    let(:inflector) { nil }

    before do
      described_class.instance_variable_set(:@inflector, inflector)
    end

    context "when inflector is available" do
      let(:inflector) do
        Class.new {
          def classify(string)
            "Classified"
          end
        }.new
      end

      it "returns the classified string" do
        allow(inflector).to receive(:classify)
        expect(described_class.new("classified").classify).to eq("Classified")

        expect(inflector).to have_received(:classify).with("classified")
      end
    end

    context "when no inflector is available" do
      it "returns the classified string" do
        expect(described_class.new("my_string").classify).to eq("MyString")
      end
    end
  end

  describe "#constantize" do
    let(:constant) { Class.new }
    let(:inflector) { nil }

    before do
      described_class.instance_variable_set(:@inflector, inflector)
      stub_const("MyConstant", constant)
    end

    context "when inflector is available" do
      let(:inflector) do
        Class.new {
          def constantize(string)
            MyConstant if string == "MyConstant"
          end
        }.new
      end

      it "returns the constantized string" do
        expect(described_class.new("MyConstant").constantize).to eq(constant)
      end
    end

    context "when no inflector is available" do
      it "returns the constantized string" do
        expect(described_class.new("MyConstant").constantize).to eq(constant)
      end
    end
  end

  describe "#underscore" do
    subject { described_class.new(arg).underscore }

    context "with capitalized string" do
      let(:arg) { "User" }

      it { is_expected.to eq("user") }
    end

    context "with camelized string" do
      let(:arg) { "UserName" }

      it { is_expected.to eq("user_name") }
    end

    context "with parameterized string" do
      let(:arg) { "foo-bar" }

      it { is_expected.to eq("foo_bar") }
    end

    context "with camelized string under a namespace" do
      let(:arg) { "Apiv2::UserName" }

      it { is_expected.to eq("apiv2/user_name") }
    end

    context "with camelized string with a root namespace" do
      let(:arg) { "::UserName" }

      it { is_expected.to eq("user_name") }
    end

    context "with a dot in the string" do
      let(:arg) { "user.name" }

      it { is_expected.to eq("user_name") }
    end

    context "with a space in the string" do
      let(:arg) { "user name" }

      it { is_expected.to eq("user_name") }
    end

    context "with multiple underscores in the string" do
      let(:arg) { "user_______name" }

      it { is_expected.to eq("user_name") }
    end
  end

  describe "#pluralize" do
    let(:inflector) { nil }

    before do
      described_class.instance_variable_set(:@inflector, inflector)
    end

    context "when inflector is available" do
      let(:inflector) do
        Class.new {
          def pluralize(string)
            "users"
          end
        }.new
      end

      it "returns the pluralized string" do
        allow(inflector).to receive(:pluralize)
        expect(described_class.new("user").pluralize).to eq("users")

        expect(inflector).to have_received(:pluralize).with("user")
      end
    end

    context "when no inflector is available" do
      it "returns the pluralized string" do
        expect(described_class.new("user").pluralize).to eq("users")
      end

      it "returns pluralized string ending with 'y'" do
        expect(described_class.new("city").pluralize).to eq("cities")
      end
    end
  end

  describe "#singularize" do
    let(:inflector) { nil }

    before do
      described_class.instance_variable_set(:@inflector, inflector)
    end

    context "when inflector is available" do
      let(:inflector) do
        Class.new {
          def singularize(string)
            "user"
          end
        }.new
      end

      it "returns the singularized string" do
        allow(inflector).to receive(:singularize)
        expect(described_class.new("users").singularize).to eq("user")

        expect(inflector).to have_received(:singularize).with("users")
      end
    end

    context "when no inflector is available" do
      it "returns the singularized string" do
        expect(described_class.new("users").singularize).to eq("user")
      end

      it "returns singularized string ending with 'ies'" do
        expect(described_class.new("cities").singularize).to eq("city")
      end
    end
  end

  describe "#camelize" do
    let(:inflector) { nil }

    before do
      described_class.instance_variable_set(:@inflector, inflector)
    end

    context "when inflector is available" do
      let(:inflector) do
        Class.new {
          def camelize(string, uppercase_first_letter)
            "User"
          end
        }.new
      end

      it "returns the camelized string" do
        allow(inflector).to receive(:camelize)
        expect(described_class.new("user").camelize).to eq("User")

        expect(inflector).to have_received(:camelize).with("user", true)
      end
    end

    context "when no inflector is available" do
      it "returns the camelized string" do
        expect(described_class.new("user").camelize).to eq("User")
      end

      it "returns the camelized string with uppercase first letter" do
        expect(described_class.new("user").camelize(true)).to eq("User")
      end

      it "returns the camelized string with lowercase first letter" do
        expect(described_class.new("user").camelize(false)).to eq("user")
      end

      it "returns the camelized string with uppercase first letter and underscore" do
        expect(described_class.new("user_name").camelize(true)).to eq("UserName")
      end

      it "returns the camelized string with lowercase first letter and underscore" do
        expect(described_class.new("user_name").camelize(false)).to eq("userName")
      end

      it "returns the camelized string with uppercase first letter and dash" do
        expect(described_class.new("user-name").camelize(true)).to eq("UserName")
      end

      it "returns the camelized string with namespace" do
        expect(described_class.new("admin/user_name").camelize(true)).to eq("Admin::UserName")
      end
    end
  end
end
