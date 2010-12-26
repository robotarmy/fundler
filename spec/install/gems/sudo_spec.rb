require "spec_helper"

describe "when using sudo", :sudo => true do
  describe "and GEM_HOME is owned by root" do
    before :each do
      chown_system_gems_to_root
    end

    it "installs" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      system_gem_path("gems/rack-1.0.0").should exist
      check system_gem_path("gems/rack-1.0.0").stat.uid.should == 0
      should_be_installed "rack 1.0"
    end

    it "installs when BUNDLE_PATH is owned by root" do
      fundle_path = tmp("owned_by_root")
      FileUtils.mkdir_p fundle_path
      sudo "chown -R root #{fundle_path}"

      ENV['BUNDLE_PATH'] = fundle_path.to_s
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      fundle_path.join("gems/rack-1.0.0").should exist
      check fundle_path.join("gems/rack-1.0.0").stat.uid.should == 0
      should_be_installed "rack 1.0"
    end

    it "installs when BUNDLE_PATH does not exist"
  end

  describe "and BUNDLE_PATH is not writable" do
    it "installs" do
      sudo "chmod ugo-w #{default_fundle_path}"
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      default_fundle_path("gems/rack-1.0.0").should exist
      should_be_installed "rack 1.0"
    end
  end

  describe "and BUNDLE_PATH is not writable" do
    it "installs" do
      begin
        gem_home = tmp('sudo_gem_home')

        sudo "mkdir -p #{gem_home}"
        sudo "chmod ugo-w #{gem_home}"
        ENV['GEM_HOME'] = gem_home.to_s
        ENV['GEM_PATH'] = nil

        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack", '1.0'
        G

        gem_home.join('bin/rackup').should exist
        should_be_installed "rack 1.0"
      end
    end
  end

end
