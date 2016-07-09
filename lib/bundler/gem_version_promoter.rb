# frozen_string_literal: true
module Bundler
  # This class contains all of the logic for determining the next version of a
  # Gem to update to based on the requested level (patch, minor, major).
  # Primarily designed to work with Resolver which will provide it the list of
  # available dependency versions as found in its index, before returning it to
  # to the resolution engine to select the best version.
  class GemVersionPromoter
    attr_reader :level, :locked_specs, :unlock_gems

    # By default, strict is false, meaning every available version of a gem
    # is returned from sort_versions. The order gives preference to the
    # requested level (:patch, :minor, :major) but in complicated requirement
    # cases some gems will by necessity by promoted past the requested level,
    # or even reverted to older versions.
    #
    # If strict is set to true, the results from sort_versions will be
    # truncated, eliminating any version outside the current level scope.
    # This can lead to unexpected outcomes or even VersionConflict exceptions
    # that report a version of a gem not existing for versions that indeed do
    # existing in the referenced source.
    attr_accessor :strict

    # Given a list of locked_specs and a list of gems to unlock creates a
    # GemVersionPromoter instance.
    #
    # @param locked_specs [SpecSet] All current locked specs. Unlike Definition
    #   where this list is empty if all gems are being updated, this should
    #   always be populated for all gems so this class can properly function.
    # @param unlock_gems [String] List of gem names being unlocked. If empty,
    #   all gems will be considered unlocked.
    # @return [GemVersionPromoter]
    def initialize(locked_specs = SpecSet.new([]), unlock_gems = [])
      @level = :major
      @strict = false
      @locked_specs = locked_specs
      @unlock_gems = unlock_gems
      @sort_versions = {}
    end

    # @param value [Symbol] One of three Symbols: :major, :minor or :patch.
    def level=(value)
      v = case value
          when String, Symbol
            value.to_sym
      end

      raise ArgumentError, "Unexpected level #{v}. Must be :major, :minor or :patch" unless [:major, :minor, :patch].include?(v)
      @level = v
    end

    # Given a Dependency and an Array of SpecGroups of available versions for a
    # gem, this method will return the Array of SpecGroups sorted (and possibly
    # truncated if strict is true) in an order to give preference to the current
    # level (:major, :minor or :patch) when resolution is deciding what versions
    # best resolve all dependencies in the bundle.
    # @param dep [Dependency] The Dependency of the gem.
    # @param spec_groups [SpecGroup] An array of SpecGroups for the same gem
    #    named in the @dep param.
    # @return [SpecGroup] A new instance of the SpecGroup Array sorted and
    #    possibly filtered.
    def sort_versions(dep, spec_groups)
      before_result = "before sort_versions: #{debug_format_result(dep, spec_groups).inspect}" if ENV["DEBUG_RESOLVER"]

      @sort_versions[dep] ||= begin
        gem_name = dep.name

        # An Array per version returned, different entries for different platforms.
        # We only need the version here so it's ok to hard code this to the first instance.
        locked_spec = locked_specs[gem_name].first

        if strict
          filter_dep_specs(spec_groups, locked_spec)
        else
          sort_dep_specs(spec_groups, locked_spec)
        end.tap do |specs|
          if ENV["DEBUG_RESOLVER"]
            STDERR.puts before_result
            STDERR.puts " after sort_versions: #{debug_format_result(dep, specs).inspect}"
          end
        end
      end
    end

    # @return [bool] Convenience method for testing value of level variable.
    def major?
      level == :major
    end

    # @return [bool] Convenience method for testing value of level variable.
    def minor?
      level == :minor
    end

  private

    def filter_dep_specs(spec_groups, locked_spec)
      res = spec_groups.select do |spec_group|
        if locked_spec && !major?
          gsv = spec_group.version
          lsv = locked_spec.version

          must_match = minor? ? [0] : [0, 1]

          matches = must_match.map {|idx| gsv.segments[idx] == lsv.segments[idx] }
          (matches.uniq == [true]) ? (gsv >= lsv) : false
        else
          true
        end
      end

      sort_dep_specs(res, locked_spec)
    end

    def sort_dep_specs(spec_groups, locked_spec)
      return spec_groups unless locked_spec
      gem_name = locked_spec.name
      locked_version = locked_spec.version

      spec_groups.sort do |a, b|
        a_ver = a.version
        b_ver = b.version
        case
        when major?
          a_ver <=> b_ver
        when either_version_older_than_locked(locked_version, a_ver, b_ver)
          a_ver <=> b_ver
        when segments_do_not_match(:major, a_ver, b_ver)
          b_ver <=> a_ver
        when !minor? && segments_do_not_match(:minor, a_ver, b_ver)
          b_ver <=> a_ver
        when !unlocking_gem?(gem_name) && one_version_matches(locked_version, a_ver, b_ver)
          sort_matching_to_end(locked_version, a_ver, b_ver)
        else
          a_ver <=> b_ver
        end
      end
    end

    def either_version_older_than_locked(locked_version, a_ver, b_ver)
      a_ver < locked_version || b_ver < locked_version
    end

    def segments_do_not_match(level, a_ver, b_ver)
      index = [:major, :minor].index(level)
      a_ver.segments[index] != b_ver.segments[index]
    end

    def unlocking_gem?(gem_name)
      unlock_gems.empty? || unlock_gems.include?(gem_name)
    end

    def one_version_matches(match_version, a_ver, b_ver)
      [a_ver, b_ver].include?(match_version)
    end

    def sort_matching_to_end(version, a_ver, b_ver)
      if a_ver == version
        1
      elsif b_ver == version
        -1
      else
        # should never happen, prevents coding error when not using
        # one_version_matches prior to calling this method
        raise "Neither version (#{a_ver} or #{b_ver}) matches #{version}"
      end
    end

    def debug_format_result(dep, spec_groups)
      a = [dep.to_s,
           spec_groups.map {|sg| [sg.version, sg.dependencies_for_activated_platforms.map {|dp| [dp.name, dp.requirement.to_s] }] }]
      last_map = a.last.map {|sg_data| [sg_data.first.version, sg_data.last.map {|aa| aa.join(" ") }] }
      [a.first, last_map, level, strict ? :strict : :not_strict]
    end
  end
end
