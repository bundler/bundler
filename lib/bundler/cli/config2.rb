# frozen_string_literal: true
module Bundler
  class CLI::Config2
    attr_reader :options, :scope, :thor, :command, :name, :value
    attr_accessor :args

    # bundle config set name value
    # bundle config unset name
    def initialize(options, args, thor)
      @options = options
      @args = args
      @thor = thor
    end

    def run
      arg0 = args.shift

      if arg0.nil?
        confirm_all
        return
      end

      while arg0.start_with?("--")
        arg0 = args.shift
      end

      if arg0 == "set" || arg0 == "unset"
        @command = arg0.to_sym
        @name = args.shift
        @value = args.shift
      else
        @name = arg0
      end

      @scope = options["global"] ? :global : :local

      return set if command == :set
      return unset if command == :unset

      # Invariant: name must be set
      raise "Name is not set" if name.nil?

      confirm(name)
    end

    def set
      Bundler.ui.info(message) if message
      Bundler.settings.send("set_#{scope}", name, value)
    end

    def unset
      scope == :global ? Bundler.settings.set_global(name, nil) : Bundler.settings.set_local(name, nil)
    end

    def message
      locations = Bundler.settings.locations(name)
      if scope == :global
        if locations[:local]
          "Your application has set #{name} to #{locations[:local].inspect}. " \
            "This will override the global value you are currently setting"
        elsif locations[:env]
          "You have a bundler environment variable for #{name} set to " \
            "#{locations[:env].inspect}. This will take precedence over the global value you are setting"
        elsif locations[:global] && locations[:global] != args.join(" ")
          "You are replacing the current global value of #{name}, which is currently " \
            "#{locations[:global].inspect}"
        end
      elsif scope == "local" && locations[:local] != args.join(" ")
        "You are replacing the current local value of #{name}, which is currently " \
          "#{locations[:local].inspect}"
      end
    end

    def confirm_all
      Bundler.ui.confirm "Settings are listed in order of priority. The top value will be used.\n"
      Bundler.settings.all.each do |setting|
        Bundler.ui.confirm "#{setting}"
        show_pretty_values_for(setting)
        Bundler.ui.confirm ""
      end
    end

    def confirm(name)
      Bundler.ui.confirm "Settings for `#{name}` in order of priority. The top value will be used"
      show_pretty_values_for(name)
    end

    def show_pretty_values_for(setting)
      thor.with_padding do
        Bundler.settings.pretty_values_for(setting).each do |line|
          Bundler.ui.info line
        end
      end
    end
  end
end
