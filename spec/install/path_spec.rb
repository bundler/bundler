require "spec_helper"

describe "bundle install" do
  describe "with path set via config" do
    before :each do
      build_gem "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "puts 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      set_bundle_path('local', 'vendor/bundle')
    end

    it "does not use available system gems" do
      bundle :install
      should_be_installed "rack 1.0.0"
    end

    it "handles paths with regex characters in them" do
      dir = bundled_app("bun++dle")
      dir.mkpath

      Dir.chdir(dir) do
        bundle :install
        expect(out).to include("installed into ./vendor/bundle")
      end

      dir.rmtree
    end

    it "prints a warning to let the user know where gems are installed" do
      bundle :install
      expect(out).to include("gems are installed into ./vendor")
    end
  end

  describe "when BUNDLE_PATH or the global path config is set" do
    before :each do
      build_lib "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    %w/env global/.each do |type|
      it "gives precedence to the local path over #{type}" do
        set_bundle_path(type, bundled_app("vendor2").to_s)
        set_bundle_path('local', 'vendor/bundle')
        bundle :install

        expect(vendored_gems("gems/rack-1.0.0")).to be_directory
        expect(bundled_app("vendor2")).not_to be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH with #{type}" do
        set_bundle_path(type, bundled_app("vendor").to_s)

        bundle :install
        expect(bundled_app("vendor/#{Bundler.ruby_scope}/gems/rack-1.0.0")).to be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH relative to root when relative" do
        # FIXME: If the bundle_path is `"vendor"` instead of
        # `bundled_app("vendor").to_s`, this spec fails. As is, this spec
        # may not test what happens when `path` is relative.

        bundle "config path vendor"
        #set_bundle_path(type, bundled_app("vendor").to_s)

        FileUtils.mkdir_p bundled_app("lol")
        Dir.chdir(bundled_app("lol")) do
          bundle :install
        end

        expect(bundled_app("vendor/#{Bundler.ruby_scope}/gems/rack-1.0.0")).to be_directory
        should_be_installed "rack 1.0.0"
      end
    end

    it "installs gems to BUNDLE_PATH from .bundle/config" do
      set_bundle_path('local', 'vendor/bundle')

      bundle :install

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end

    it "disables system gems when passing a path to install" do
      # This is so that vendored gems can be distributed to others
      build_gem "rack", "1.1.0", :to_system => true
      set_bundle_path('local', 'vendor/bundle')
      bundle :install

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end
  end

  describe "to a dead symlink" do
    before do
      in_app_root do
        `ln -s /tmp/idontexist bundle`
      end
    end

    it "reports the symlink is dead" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      set_bundle_path('local', 'bundle')
      bundle :install
      expect(out).to match(/invalid symlink/)
    end
  end

  def set_bundle_path(type, location)
    case type
    when 'env'
      ENV["BUNDLE_PATH"] = location
    when 'global', 'local'
      bundle "config --#{type} path #{location}", "no-color" => nil
    end
  end
end
