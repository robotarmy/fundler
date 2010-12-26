require "spec_helper"

describe "fundle install for the first time with v1.0" do
  before :each do
    in_app_root

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  it "removes lockfiles in 0.9 YAML format" do
    File.open("Gemfile.lock", "w"){|f| YAML.dump({}, f) }
    fundle :install
    File.read("Gemfile.lock").should_not =~ /^---/
  end

  it "removes env.rb if it exists" do
    fundled_app.join(".fundle").mkdir
    fundled_app.join(".fundle/environment.rb").open("w"){|f| f.write("raise 'nooo'") }
    fundle :install
    fundled_app.join(".fundle/environment.rb").should_not exist
  end

end
