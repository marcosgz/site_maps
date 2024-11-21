require "thor"

module SiteMaps
  class CLI < Thor
    method_option :debug, type: :boolean, default: false
    method_option :logfile, type: :string, default: nil
    method_option :pidfile, type: :string, default: nil
    method_option :config_file, type: :string, aliases: "-r", default: nil
    method_option :max_threads, type: :numeric, aliases: "-c", default: 4
    method_option :context, type: :hash, default: {}

    desc "generate 1st_process,2nd_process ... ,Nth_process", "Generate sitemap.xml files for the given processes"
    default_command :start

    def generate(processes = "")
      load_rails if rails_app?

      opts = (@options || {}).transform_keys(&:to_sym)
      if (logfile = opts.delete(:logfile))
        SiteMaps.logger = Logger.new(logfile)
      end
      if opts.delete(:debug)
        SiteMaps.logger.level = Logger::DEBUG
      end

      SiteMaps::Notification.subscribe(SiteMaps::Runner::EventListener)

      runner = SiteMaps.generate(
        config_file: opts.delete(:config_file),
        max_threads: opts.delete(:max_threads)
      )
      if processes.empty?
        runner.enqueue_all
      else
        kwargs = opts.delete(:context) { {} }.transform_keys(&:to_sym)
        processes.split(",").each do |process|
          runner.enqueue(process.strip.to_sym, **kwargs)
        end
      end

      runner.run
    end

    desc "version", "Print the version"
    def version
      puts "SiteMaps version: #{SiteMaps::VERSION}"
    end

    default_task :help

    private

    def rails_app?
      File.exist?(File.join(Dir.pwd, "config", "application.rb"))
    end

    def load_rails
      require File.expand_path(File.join(Dir.pwd, "config", "application.rb"))
      require_relative "railtie"

      ::Rails.application.require_environment!
    end
  end
end
