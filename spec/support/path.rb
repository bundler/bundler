require "pathname"

module Spec
  module Path
    def root
      @root ||= Pathname.new(File.expand_path("../../..", __FILE__))
    end

    def tmp(*path)
      root.join("tmp", *path)
    end

    def home(*path)
      tmp.join("home", *path)
    end

    def default_bundle_path(*path)
      bundled_app(".bundle", Bundler.ruby_scope, *path)
    end

    def bundled_app(*path)
      root = tmp.join("bundled_app")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    alias_method :bundled_app1, :bundled_app

    def bundled_app2(*path)
      root = tmp.join("bundled_app2")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    def vendored_gems(path = nil)
      bundled_app(*["vendor/bundle", Gem.ruby_engine, Gem::ConfigMap[:ruby_version], path].compact)
    end

    def cached_gem(path)
      bundled_app("vendor/cache/#{path}.gem")
    end

    def bundle_cache(*path)
      home(".bundle/cache", *path)
    end

    def source_dir(source)
      prefix = %r(https?:\/\/) =~ source.to_s ? "" : "file:"
      uri = Bundler::Source::Rubygems::Remote.new(URI("#{prefix}#{source}/")).uri
      [uri.hostname, uri.port, Digest::MD5.hexdigest(uri.path)].compact.join(".")
    end

    def bundle_cache_source_dir(source)
      bundle_cache("gems", source_dir(source))
    end

    def bundle_cached_gem(gem, source = nil)
      if source
        bundle_cache_source_dir(source).join("#{gem}.gem")
      else
        bundle_cache("gems", "#{gem}.gem")
      end
    end

    def base_system_gems
      tmp.join("gems/base")
    end

    def gem_repo1(*args)
      tmp("gems/remote1", *args)
    end

    def gem_repo_missing(*args)
      tmp("gems/missing", *args)
    end

    def gem_repo2(*args)
      tmp("gems/remote2", *args)
    end

    def gem_repo3(*args)
      tmp("gems/remote3", *args)
    end

    def gem_repo4(*args)
      tmp("gems/remote4", *args)
    end

    def security_repo(*args)
      tmp("gems/security_repo", *args)
    end

    def system_gem_path(*path)
      tmp("gems/system", *path)
    end

    def lib_path(*args)
      tmp("libs", *args)
    end

    def bundler_path
      Pathname.new(File.expand_path("../../../lib", __FILE__))
    end

    extend self
  end
end
