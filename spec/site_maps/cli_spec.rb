# frozen_string_literal: true

require "spec_helper"
require "site_maps/cli"

RSpec.describe SiteMaps::CLI do
  let(:cli) { SiteMaps::CLI.new }

  describe "#version" do
    subject(:version!) { cli.version }

    it "prints the version" do
      expect { version! }.to output(/SiteMaps version: #{SiteMaps::VERSION}/).to_stdout
    end
  end

  describe "#generate" do
    context "with no processes" do
      subject(:generate!) { cli.generate }

      it "enqueues all processes" do
        runner = double("runner", enqueue_all: nil, run: nil)
        allow(SiteMaps).to receive(:generate).and_return(runner)

        generate!

        expect(runner).to have_received(:enqueue_all)
        expect(runner).to have_received(:run)
      end
    end

    context "with processes" do
      subject(:generate!) { cli.generate(processes) }

      let(:processes) { "default,categories" }

      it "enqueues the given processes" do
        runner = double("runner", enqueue: nil, run: nil)
        allow(SiteMaps).to receive(:generate).and_return(runner)

        generate!

        expect(runner).to have_received(:enqueue).with(:default, {})
        expect(runner).to have_received(:enqueue).with(:categories, {})
        expect(runner).to have_received(:run)
      end
    end

    context "with options" do
      subject(:generate!) { cli.generate(processes) }

      let(:processes) { "default" }
      let(:options) do
        {
          debug: true,
          logfile: "/tmp/site_maps.log",
          max_threads: 8,
          context: { "year" => "2022", "month" => "2"}
        }
      end

      before do
        cli.instance_variable_set(:@options, options)
      end

      it "passes the options to the runner" do
        runner = double("runner", enqueue: nil, run: nil)
        allow(SiteMaps).to receive(:generate).and_return(runner)

        generate!

        expect(runner).to have_received(:enqueue).with(:default, year: "2022", month: "2")
        expect(runner).to have_received(:run)
      end
    end
  end
end
