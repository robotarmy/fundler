require "spec_helper"

describe "fundle update" do
  before :each do
    build_repo2

    install_gemfile <<-G
      source "file://#{gem_repo2}"
      gem "activesupport"
      gem "rack-obama"
    G
  end

  describe "with no arguments" do
    it "updates the entire fundle" do
      update_repo2 do
        build_gem "activesupport", "3.0"
      end

      fundle "update"
      should_be_installed "rack 1.2", "rack-obama 1.0", "activesupport 3.0"
    end

    it "doesn't delete the Gemfile.lock file if something goes wrong" do
      gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activesupport"
        gem "rack-obama"
        exit!
      G
      fundle "update"
      fundled_app("Gemfile.lock").should exist
    end
  end

  describe "with a top level dependency" do
    it "unlocks all child dependencies that are unrelated to other locked dependencies" do
      update_repo2 do
        build_gem "activesupport", "3.0"
      end

      fundle "update rack-obama"
      should_be_installed "rack 1.2", "rack-obama 1.0", "activesupport 2.3.5"
    end
  end
end

describe "fundle update in more complicated situations" do
  before :each do
    build_repo2
  end

  it "will eagerly unlock dependencies of a specified gem" do
    install_gemfile <<-G
      source "file://#{gem_repo2}"

      gem "thin"
      gem "rack-obama"
    G

    update_repo2 do
      build_gem "thin" , '2.0' do |s|
        s.add_dependency "rack"
      end
    end

    fundle "update thin"
    should_be_installed "thin 2.0", "rack 1.2", "rack-obama 1.0"
  end
end

describe "fundle update without a Gemfile.lock" do
  it "should not explode" do
    build_repo2

    gemfile <<-G
      source "file://#{gem_repo2}"

      gem "rack", "1.0"
    G

    fundle "update"

    should_be_installed "rack 1.0.0"
  end
end

describe "fundle update when a gem depends on a newer version of fundler" do
  before(:each) do
    build_repo2 do
      build_gem "rails", "3.0.1" do |s|
        s.add_dependency "fundler", Fundler::VERSION.succ
      end
    end

    gemfile <<-G
      source "file://#{gem_repo2}"
      gem "rails", "3.0.1"
    G
  end

  it "should not explode" do
    fundle "update"
    err.should be_empty
  end

  it "should explain that fundler conflicted" do
    fundle "update"
    out.should_not =~ /In snapshot/
    out.should =~ /Current Fundler version/
  end
end
