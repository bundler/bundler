require "spec_helper"

describe "bundle changelog" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G
  end

  describe "searches for different changelog files" do

    [ "CHANGELOG.md", "history.rdoc", "changes.txt", "changeLog" ].each do |changelog|

      it "prints the file CHANGELOG.md" do
        File.open File.join(default_bundle_path('gems', 'rails-2.3.2'), changelog), "w" do |f|
          f.puts "This is the contents of the changelog file"
        end

        bundle "changelog rails"
        expect(out).to eq("This is the contents of the changelog file")
      end

    end
  end

  it "complains if a changelog wasn't found" do
    bundle "changelog rails"
    expect(out).to match(/No Changelog found for 'rails'/i)
  end

  it "complains if gem not in bundle" do
    bundle "changelog missing"
    expect(out).to match(/could not find gem 'missing'/i)
  end

end
