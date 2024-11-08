# frozen_string_literal: true

require "rails/railtie"

module SiteMaps
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "site_maps/tasks.rb"
    end
  end
end
