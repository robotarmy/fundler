require "spec_helper"

describe "fundle cache" do

  describe "when there are only gemsources" do
    before :each do
      gemfile <<-G
        gem 'rack'
      G

      system_gems "rack-1.0.0"
      fundle :cache
    end

    it "copies the .gem file to vendor/cache" do
      fundled_app("vendor/cache/rack-1.0.0.gem").should exist
    end

    it "uses the cache as a source when installing gems" do
      build_gem "omg", :path => fundled_app('vendor/cache')

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "omg"
      G

      should_be_installed "omg 1.0.0"
    end

    it "uses the cache as a source when installing gems with --local" do
      system_gems []
      fundle "install --local"

      should_be_installed("rack 1.0.0")
    end

    it "does not reinstall gems from the cache if they exist on the system" do
      build_gem "rack", "1.0.0", :path => fundled_app('vendor/cache') do |s|
        s.write "lib/rack.rb", "RACK = 'FAIL'"
      end

      install_gemfile <<-G
        gem "rack"
      G

      should_be_installed("rack 1.0.0")
    end

    it "does not reinstall gems from the cache if they exist in the fundle" do
      system_gems "rack-1.0.0"

      gemfile <<-G
        gem "rack"
      G

      build_gem "rack", "1.0.0", :path => fundled_app('vendor/cache') do |s|
        s.write "lib/rack.rb", "RACK = 'FAIL'"
      end

      fundle "install --local"
      should_be_installed("rack 1.0.0")
    end

    it "creates a lockfile" do
      cache_gems "rack-1.0.0"

      gemfile <<-G
        gem "rack"
      G

      fundle "cache"

      fundled_app("Gemfile.lock").should exist
    end
  end

  describe "when there are also git sources" do
    before do
      build_git "foo"
      system_gems "rack-1.0.0"

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        git "#{lib_path("foo-1.0")}" do
          gem 'foo'
        end
        gem 'rack'
      G
    end

    it "still works" do
      fundle :cache

      system_gems []
      fundle "install --local"

      should_be_installed("rack 1.0.0", "foo 1.0")
    end

    it "should not explode if the lockfile is not present" do
      FileUtils.rm(fundled_app("Gemfile.lock"))

      fundle :cache

      fundled_app("Gemfile.lock").should exist
    end
  end

  describe "when previously cached" do
    before :each do
      build_repo2
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
        gem "actionpack"
      G
      fundle :cache
      cached_gem("rack-1.0.0").should exist
      cached_gem("actionpack-2.3.2").should exist
      cached_gem("activesupport-2.3.2").should exist
    end

    it "re-caches during install" do
      cached_gem("rack-1.0.0").rmtree
      fundle :install
      out.should include("Updating .gem files in vendor/cache")
      cached_gem("rack-1.0.0").should exist
    end

    it "adds and removes when gems are updated" do
      update_repo2
      fundle 'update'
      cached_gem("rack-1.2").should exist
      cached_gem("rack-1.0.0").should_not exist
    end

    it "adds new gems and dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails"
      G
      cached_gem("rails-2.3.2").should exist
      cached_gem("activerecord-2.3.2").should exist
    end

    it "removes .gems for removed gems and dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G
      cached_gem("rack-1.0.0").should exist
      cached_gem("actionpack-2.3.2").should_not exist
      cached_gem("activesupport-2.3.2").should_not exist
    end

    it "removes .gems when gem changes to git source" do
      build_git "rack"

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack", :git => "#{lib_path("rack-1.0")}"
        gem "actionpack"
      G
      cached_gem("rack-1.0.0").should_not exist
      cached_gem("actionpack-2.3.2").should exist
      cached_gem("activesupport-2.3.2").should exist
    end


    it "doesn't remove gems that are for another platform" do
      simulate_platform "java" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        fundle :cache
        cached_gem("platform_specific-1.0-java").should exist
      end

      simulate_new_machine
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "platform_specific"
      G

      cached_gem("platform_specific-1.0-#{Gem::Platform.local}").should exist
      cached_gem("platform_specific-1.0-java").should exist
    end

    it "doesn't remove gems with mismatched :rubygems_version or :date" do
      cached_gem("rack-1.0.0").rmtree
      build_gem "rack", "1.0.0",
        :path => fundled_app('vendor/cache'),
        :rubygems_version => "1.3.2"
      simulate_new_machine

      fundle :install
      cached_gem("rack-1.0.0").should exist
    end

    it "handles directories and non .gem files in the cache" do
      fundled_app("vendor/cache/foo").mkdir
      File.open(fundled_app("vendor/cache/bar"), 'w'){|f| f.write("not a gem") }
      fundle :cache
    end

    it "does not say that it is removing gems when it isn't actually doing so" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      fundle "cache"
      fundle "install"
      out.should_not =~ /removing/i
    end
  end

end
