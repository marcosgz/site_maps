require "timecop"

module Hooks
  module Timecop
    def self.included(base)
      base.before do |example|
        next unless example.metadata[:freeze_at]

        ::Timecop.freeze(*example.metadata[:freeze_at])
      end

      base.after do |example|
        ::Timecop.return if example.metadata[:freeze_at]
      end
    end
  end
end

RSpec.configure do |config|
  config.include Hooks::Timecop
end
