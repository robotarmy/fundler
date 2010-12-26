require "spec_helper"

describe "fundle install with gem sources" do
  describe "when cached and locked" do
    it "does not hit the remote at all" do
      build_repo2
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G

      fundle :pack
      simulate_new_machine
      FileUtils.rm_rf gem_repo2

      fundle "install --local"
      should_be_installed "rack 1.0.0"
    end

    it "does not hit the remote at all" do
      build_repo2
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G

      fundle :pack
      simulate_new_machine
      FileUtils.rm_rf gem_repo2

      fundle "install --deployment"
      should_be_installed "rack 1.0.0"
    end

    it "does not reinstall already-installed gems" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      fundle :pack

      build_gem "rack", "1.0.0", :path => fundled_app('vendor/cache') do |s|
        s.write "lib/rack.rb", "raise 'omg'"
      end

      fundle :install
      err.should be_empty
      should_be_installed "rack 1.0"
    end

    it "ignores cached gems for the wrong platform" do
      simulate_platform "java" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G
        fundle :pack
      end

      simulate_new_machine

      simulate_platform "ruby" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G
        run "require 'platform_specific' ; puts PLATFORM_SPECIFIC"
        out.should == "1.0.0 RUBY"
      end
    end
  end
end
