# frozen_string_literal: true

module Bundler
  class CLI::Info
    attr_reader :gem_name, :options
    def initialize(options, gem_name)
      @options = options
      @gem_name = gem_name
    end

    def run
      Bundler.ui.silence do
        Bundler.definition.validate_runtime!
        Bundler.load.lock
      end

      spec = spec_for_gem(gem_name)

      if spec
        return print_gem_path(spec) if @options[:path]
        print_gem_info(spec)
      end
    end

  private

    def spec_for_gem(gem_name)
      spec = Bundler.definition.specs.find {|s| s.name == gem_name }
      spec || default_gem_spec(gem_name) || Bundler::CLI::Common.select_spec(gem_name, :regex_match)
    end

    def default_gem_spec(gem_name)
      return unless Gem::Specification.respond_to?(:find_all_by_name)
      gem_spec = Gem::Specification.find_all_by_name(gem_name).last
      return gem_spec if gem_spec && gem_spec.respond_to?(:default_gem?) && gem_spec.default_gem?
    end

    def spec_not_found(gem_name)
      raise GemNotFound, Bundler::CLI::Common.gem_not_found_message(gem_name, Bundler.definition.dependencies)
    end

    def print_gem_path(spec)
      path = if spec.name == "bundler"
        File.expand_path("../../../..", __FILE__)
      else
        spec.full_gem_path
      end

      Bundler.ui.info path
    end

    def print_gem_info(spec)
      gem_info = String.new
      gem_info << "  * #{spec.name} (#{spec.version}#{spec.git_version})\n"
      gem_info << "\tSummary: #{spec.summary}\n" if spec.summary
      gem_info << "\tHomepage: #{spec.homepage}\n" if spec.homepage
      gem_info << "\tPath: #{spec.full_gem_path}\n"
      gem_info << "\tDefault Gem: yes\n" if spec.respond_to?(:default_gem?) && spec.default_gem?
      gem_info << "\tDependencies:\n"
      gem_info << "\t\t#{gem_dependencies.join("\n\t\t")}\n"
      Bundler.ui.info gem_info
    end

    def gem_dependencies
      dependencies = Bundler.definition.specs.map do |spec|
        dependency = spec.dependencies.find {|dep| dep.name == gem_name }
        next unless dependency
        requirements_list = dependency.requirements_list
        requirements_list << "any version" if requirements_list.empty?
        "#{spec.name} (#{spec.version}) depends on #{gem_name} (#{requirements_list.join(", ")})"
      end.compact.sort
      dependencies << "(none)" if dependencies.empty?
      dependencies
    end
  end
end
