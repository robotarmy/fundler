require "spec_helper"

describe "fundle install with gem sources" do
  describe "the simple case" do
    it "prints output and returns if no dependencies are specified" do
      gemfile <<-G
        source "file://#{gem_repo1}"
      G

      fundle :install
      out.should =~ /no dependencies/
    end

    it "does not make a lockfile if the install fails" do
      install_gemfile <<-G, :expect_err => true
        raise StandardError, "FAIL"
      G

      err.should =~ /FAIL \(StandardError\)/
      fundled_app("Gemfile.lock").should_not exist
    end

    it "creates a Gemfile.lock" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      fundled_app('Gemfile.lock').should exist
    end

    it "creates lock files based on the Gemfile name" do
      gemfile fundled_app('OmgFile'), <<-G
        source "file://#{gem_repo1}"
        gem "rack", "1.0"
      G

      fundle 'install --gemfile OmgFile'

      fundled_app("OmgFile.lock").should exist
    end

    it "doesn't delete the lockfile if one already exists" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      lockfile = File.read(fundled_app("Gemfile.lock"))

      install_gemfile <<-G, :expect_err => true
        raise StandardError, "FAIL"
      G

      File.read(fundled_app("Gemfile.lock")).should == lockfile
    end

    it "does not touch the lockfile if nothing changed" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lambda { run '1' }.should_not change { File.mtime(fundled_app('Gemfile.lock')) }
    end

    it "fetches gems" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      default_fundle_path("gems/rack-1.0.0").should exist
      should_be_installed("rack 1.0.0")
    end

    it "fetches gems when multiple versions are specified" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem 'rack', "> 0.9", "< 1.0"
      G

      default_fundle_path("gems/rack-0.9.1").should exist
      should_be_installed("rack 0.9.1")
    end

    it "fetches gems when multiple versions are specified take 2" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem 'rack', "< 1.0", "> 0.9"
      G

      default_fundle_path("gems/rack-0.9.1").should exist
      should_be_installed("rack 0.9.1")
    end

    it "raises an appropriate error when gems are specified using symbols" do
      status = install_gemfile(<<-G, :exitstatus => true)
        source "file://#{gem_repo1}"
        gem :rack
      G
      status.should == 4
    end

    it "pulls in dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G

      should_be_installed "actionpack 2.3.2", "rails 2.3.2"
    end

    it "does the right version" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", "0.9.1"
      G

      should_be_installed "rack 0.9.1"
    end

    it "does not install the development dependency" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "with_development_dependency"
      G

      should_be_installed "with_development_dependency 1.0.0"
      should_not_be_installed "activesupport 2.3.5"
    end

    it "resolves correctly" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "activemerchant"
        gem "rails"
      G

      should_be_installed "activemerchant 1.0", "activesupport 2.3.2", "actionpack 2.3.2"
    end

    it "activates gem correctly according to the resolved gems" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "activesupport", "2.3.5"
      G

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "activemerchant"
        gem "rails"
      G

      should_be_installed "activemerchant 1.0", "activesupport 2.3.2", "actionpack 2.3.2"
    end

    it "does not reinstall any gem that is already available locally" do
      system_gems "activesupport-2.3.2"

      build_repo2 do
        build_gem "activesupport", "2.3.2" do |s|
          s.write "lib/activesupport.rb", "ACTIVESUPPORT = 'fail'"
        end
      end

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activerecord", "2.3.2"
      G

      should_be_installed "activesupport 2.3.2"
    end

    it "works when the gemfile specifies gems that only exist in the system" do
      build_gem "foo", :to_system => true
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "foo"
      G

      should_be_installed "rack 1.0.0", "foo 1.0.0"
    end

    it "prioritizes local gems over remote gems" do
      build_gem 'rack', '1.0.0', :to_system => true do |s|
        s.add_dependency "activesupport", "2.3.5"
      end

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      should_be_installed "rack 1.0.0", "activesupport 2.3.5"
    end

    describe "with a gem that installs multiple platforms" do
      it "installs gems for the local platform as first choice" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        run "require 'platform_specific' ; puts PLATFORM_SPECIFIC"
        out.should == "1.0.0 #{Gem::Platform.local}"
      end

      it "falls back on plain ruby" do
        simulate_platform "foo-bar-baz"
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        run "require 'platform_specific' ; puts PLATFORM_SPECIFIC"
        out.should == "1.0.0 RUBY"
      end

      it "installs gems for java" do
        simulate_platform "java"
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        run "require 'platform_specific' ; puts PLATFORM_SPECIFIC"
        out.should == "1.0.0 JAVA"
      end

      it "installs gems for windows" do
        simulate_platform mswin

        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        run "require 'platform_specific' ; puts PLATFORM_SPECIFIC"
        out.should == "1.0.0 MSWIN"
      end
    end

    describe "doing fundle install foo" do
      before do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G
      end

      it "works" do
        fundle "install --path vendor"
        should_be_installed "rack 1.0"
      end

      it "allows running fundle install --system without deleting foo" do
        fundle "install --path vendor"
        fundle "install --system"
        FileUtils.rm_rf(fundled_app("vendor"))
        should_be_installed "rack 1.0"
      end

      it "allows running fundle install --system after deleting foo" do
        fundle "install --path vendor"
        FileUtils.rm_rf(fundled_app("vendor"))
        fundle "install --system"
        should_be_installed "rack 1.0"
      end
    end

    it "finds gems in multiple sources" do
      build_repo2
      update_repo2

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        source "file://#{gem_repo2}"

        gem "activesupport", "1.2.3"
        gem "rack", "1.2"
      G

      should_be_installed "rack 1.2", "activesupport 1.2.3"
    end

    it "gives a useful error if no sources are set" do
      install_gemfile <<-G
        gem "rack"
      G

      fundle :install, :expect_err => true
      out.should =~ /Your Gemfile doesn't have any sources/i
    end
  end

  describe "when prerelease gems are available" do
    it "finds prereleases" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "not_released"
      G
      should_be_installed "not_released 1.0.pre"
    end

    it "uses regular releases if available" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "has_prerelease"
      G
      should_be_installed "has_prerelease 1.0"
    end

    it "uses prereleases if requested" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "has_prerelease", "1.1.pre"
      G
      should_be_installed "has_prerelease 1.1.pre"
    end
  end

  describe "when prerelease gems are not available" do
    it "still works" do
      build_repo3
      install_gemfile <<-G
        source "file://#{gem_repo3}"
        gem "rack"
      G

      should_be_installed "rack 1.0"
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

    def set_fundle_path(type, location)
      if type == :env
        ENV["BUNDLE_PATH"] = location
      elsif type == :global
        fundle "config path #{location}", "no-color" => nil
      end
    end

    [:env, :global].each do |type|
      it "installs gems to a path if one is specified" do
        set_fundle_path(type, fundled_app("vendor2").to_s)
        fundle "install --path vendor/fundle"

        vendored_gems("gems/rack-1.0.0").should be_directory
        fundled_app("vendor2").should_not be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH with #{type}" do
        set_fundle_path(type, fundled_app("vendor").to_s)

        fundle :install

        fundled_app('vendor/gems/rack-1.0.0').should be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH relative to root when relative" do
        set_fundle_path(type, "vendor")

        FileUtils.mkdir_p fundled_app('lol')
        Dir.chdir(fundled_app('lol')) do
          fundle :install
        end

        fundled_app('vendor/gems/rack-1.0.0').should be_directory
        should_be_installed "rack 1.0.0"
      end
    end

    it "installs gems to BUNDLE_PATH from .fundle/config" do
      config "BUNDLE_PATH" => fundled_app("vendor/fundle").to_s

      fundle :install

      vendored_gems('gems/rack-1.0.0').should be_directory
      should_be_installed "rack 1.0.0"
    end

    it "sets BUNDLE_PATH as the first argument to fundle install" do
      fundle "install --path ./vendor/fundle"

      vendored_gems('gems/rack-1.0.0').should be_directory
      should_be_installed "rack 1.0.0"
    end

    it "disables system gems when passing a path to install" do
      # This is so that vendored gems can be distributed to others
      build_gem "rack", "1.1.0", :to_system => true
      fundle "install --path ./vendor/fundle"

      vendored_gems('gems/rack-1.0.0').should be_directory
      should_be_installed "rack 1.0.0"
    end
  end

  describe "when passing in a Gemfile via --gemfile" do
    it "finds the gemfile" do
      gemfile fundled_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      fundle :install, :gemfile => fundled_app("NotGemfile")

      ENV['BUNDLE_GEMFILE'] = "NotGemfile"
      should_be_installed "rack 1.0.0"
    end
  end

  describe "when requesting a quiet install via --quiet" do
    it "should be quiet if there are no warnings" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      fundle :install, :quiet => true
      out.should == ""
    end

    it "should still display warnings" do
      gemfile <<-G
        gem 'rack'
      G

      fundle :install, :quiet => true
      out.should =~ /doesn't have any sources/
    end
  end

  describe "when disabling system gems" do
    before :each do
      build_gem "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "puts 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "behaves like fundle install vendor/fundle with --deployment" do
      fundle "install"
      fundle "install --deployment"
      out.should include("It was installed into ./vendor/fundle")
      should_be_installed "rack 1.0.0"
      fundled_app("vendor/fundle").should exist
    end

    it "prints a warning if you try to use --disable-shared-gems" do
      fundle "install --path vendor --disable-shared-gems"
      out.should include "The disable-shared-gem option is no longer available"
    end

    ["install vendor/fundle", "install --path vendor/fundle"].each do |install|
      if install == "install vendor/fundle"
        it "displays the deprecation warning for path as an argument to install" do
          fundle install
          out.should include("The path argument to `fundle install` is deprecated.")
        end
      end

      it "does not use available system gems with fundle #{install}" do
        fundle install
        should_be_installed "rack 1.0.0"
      end

      it "prints a warning to let the user know what has happened with fundle #{install}" do
        fundle install
        out.should include("It was installed into ./vendor")
      end

      it "disallows #{install} --system" do
        fundle "#{install} --system"
        out.should include("Please choose.")
      end

      it "remembers to disable system gems after the first time with fundle #{install}" do
        fundle install
        FileUtils.rm_rf fundled_app('vendor')
        fundle "install"

        vendored_gems('gems/rack-1.0.0').should be_directory
        should_be_installed "rack 1.0.0"
      end
    end
  end

  describe "when loading only the default group" do
    it "should not load all groups" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "activesupport", :group => :development
      G

      ruby <<-R
        require "fundler"
        Fundler.setup :default
        Fundler.require :default
        puts RACK
        begin
          require "activesupport"
        rescue LoadError
          puts "no activesupport"
        end
      R

      out.should include("1.0")
      out.should include("no activesupport")
    end
  end

  describe "when a gem has a YAML gemspec" do
    before :each do
      build_repo2 do
        build_gem "yaml_spec", :gemspec => :yaml
      end
    end

    it "still installs correctly" do
      gemfile <<-G
        source "file://#{gem_repo2}"
        gem "yaml_spec"
      G
      fundle :install
      err.should be_empty
    end
  end

  describe "when the gem has an architecture in its platform" do
    it "still installs correctly" do
      simulate_platform mswin

      gemfile <<-G
        # Set up pretend http gem server with FakeWeb
        $LOAD_PATH.unshift '#{Dir[base_system_gems.join("gems/fakeweb*/lib")].first}'
        require 'fakeweb'
        FakeWeb.allow_net_connect = false
        files = [ 'specs.4.8.gz',
                  'prerelease_specs.4.8.gz',
                  'quick/Marshal.4.8/rcov-1.0-mswin32.gemspec.rz',
                  'gems/rcov-1.0-mswin32.gem' ]
        files.each do |file|
          FakeWeb.register_uri(:get, "http://localgemserver.com/\#{file}",
            :body => File.read("#{gem_repo1}/\#{file}"))
        end
        FakeWeb.register_uri(:get, "http://localgemserver.com/gems/rcov-1.0-x86-mswin32.gem",
          :status => ["404", "Not Found"])

        # Try to install gem with nil arch
        source "http://localgemserver.com/"
        gem "rcov"
      G
      fundle :install
      should_be_installed "rcov 1.0.0"
    end
  end

  describe "fundler dependencies" do
    before(:each) do
      build_repo2 do
        build_gem "rails", "3.0" do |s|
          s.add_dependency "fundler", ">= 0.9.0.pre"
        end
        build_gem "fundler", "0.9.1"
        build_gem "fundler", Fundler::VERSION
      end
    end

    it "are forced to the current fundler version" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      should_be_installed "fundler #{Fundler::VERSION}"
    end

    it "are not added if not already present" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      should_not_be_installed "fundler #{Fundler::VERSION}"
    end

    it "causes a conflict if explicitly requesting a different version" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
        gem "fundler", "0.9.2"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, '')
        Fetching source index for file:#{gem_repo2}/
        Fundler could not find compatible versions for gem "fundler":
          In Gemfile:
            fundler (= 0.9.2)

          Current Fundler version:
            fundler (#{Fundler::VERSION})
        E
      out.should == nice_error
    end

    it "works for gems with multiple versions in its dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"

        gem "multiple_versioned_deps"
      G


      install_gemfile <<-G
        source "file://#{gem_repo2}"

        gem "multiple_versioned_deps"
        gem "rack"
      G

      should_be_installed "multiple_versioned_deps 1.0.0"
    end

    it "includes fundler in the fundle when it's a child dependency" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      run "begin; gem 'fundler'; puts 'WIN'; rescue Gem::LoadError; puts 'FAIL'; end"
      out.should == "WIN"
    end

    it "allows gem 'fundler' when Fundler is not in the Gemfile or its dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G

      run "begin; gem 'fundler'; puts 'WIN'; rescue Gem::LoadError => e; puts e.backtrace; end"
      out.should == "WIN"
    end

    it "causes a conflict if child dependencies conflict" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activemerchant"
        gem "rails_fail"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, '')
        Fetching source index for file:#{gem_repo2}/
        Fundler could not find compatible versions for gem "activesupport":
          In Gemfile:
            activemerchant depends on
              activesupport (>= 2.0.0)

            rails_fail depends on
              activesupport (1.2.3)
      E
      out.should == nice_error
    end

    it "causes a conflict if a child dependency conflicts with the Gemfile" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails_fail"
        gem "activesupport", "2.3.5"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, '')
        Fetching source index for file:#{gem_repo2}/
        Fundler could not find compatible versions for gem "activesupport":
          In Gemfile:
            rails_fail depends on
              activesupport (= 1.2.3)

            activesupport (2.3.5)
      E
      out.should == nice_error
    end

    it "can install dependencies even if " do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      simulate_fundler_version "10.0.0"
      #simulate_new_machine

      fundle "check"
      out.should == "The Gemfile's dependencies are satisfied"
    end
  end

  describe "when locked and installed with --without" do
    before(:each) do
      build_repo2
      system_gems "rack-0.9.1" do
        install_gemfile <<-G, :without => :rack
          source "file://#{gem_repo2}"
          gem "rack"

          group :rack do
            gem "rack_middleware"
          end
        G
      end
    end

    it "uses the correct versions even if --without was used on the original" do
      should_be_installed "rack 0.9.1"
      should_not_be_installed "rack_middleware 1.0"
      simulate_new_machine

      fundle :install

      should_be_installed "rack 0.9.1"
      should_be_installed "rack_middleware 1.0"
    end

    it "does not hit the remote a second time" do
      FileUtils.rm_rf gem_repo2
      fundle "install --without rack"
      err.should be_empty
    end
  end
end
