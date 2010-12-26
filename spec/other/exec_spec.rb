require "spec_helper"

describe "fundle exec" do
  before :each do
    system_gems "rack-1.0.0", "rack-0.9.1"
  end

  it "activates the correct gem" do
    gemfile <<-G
      gem "rack", "0.9.1"
    G

    fundle "exec rackup"
    out.should == "0.9.1"
  end

  it "works when the bins are in ~/.fundle" do
    install_gemfile <<-G
      gem "rack"
    G

    fundle "exec rackup"
    out.should == "1.0.0"
  end

  it "works when running from a random directory" do
    install_gemfile <<-G
      gem "rack"
    G

    fundle "exec 'cd #{tmp('gems')} && rackup'"

    out.should == "1.0.0"
  end

  it "handles different versions in different fundles" do
    build_repo2 do
      build_gem "rack_two", "1.0.0" do |s|
        s.executables = "rackup"
      end
    end

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "0.9.1"
    G

    Dir.chdir fundled_app2 do
      install_gemfile fundled_app2('Gemfile'), <<-G
        source "file://#{gem_repo2}"
        gem "rack_two", "1.0.0"
      G
    end

    fundle "exec rackup"

    check out.should == "0.9.1"

    Dir.chdir fundled_app2 do
      fundle "exec rackup"
      out.should == "1.0.0"
    end
  end

  it "handles gems installed with --without" do
    install_gemfile <<-G, :without => :middleware
      source "file://#{gem_repo1}"
      gem "rack" # rack 0.9.1 and 1.0 exist

      group :middleware do
        gem "rack_middleware" # rack_middleware depends on rack 0.9.1
      end
    G

    fundle "exec rackup"

    check out.should == "0.9.1"
    should_not_be_installed "rack_middleware 1.0"
  end

  it "should not duplicate already exec'ed RUBYOPT or PATH" do
    install_gemfile <<-G
      gem "rack"
    G

    rubyopt = "-I#{fundler_path} -rfundler/setup"

    fundle "exec 'echo $RUBYOPT'"
    out.should have_rubyopts(rubyopt)

    fundle "exec 'echo $RUBYOPT'", :env => {"RUBYOPT" => rubyopt}
    out.should have_rubyopts(rubyopt)
  end

  it "errors nicely when the argument doesn't exist" do
    install_gemfile <<-G
      gem "rack"
    G

    fundle "exec foobarbaz", :exitstatus => true
    check exitstatus.should == 127
    out.should include("fundler: command not found: foobarbaz")
    out.should include("Install missing gem binaries with `fundle install`")
  end

  it "errors nicely when the argument is not executable" do
    install_gemfile <<-G
      gem "rack"
    G

    fundle "exec touch foo"
    fundle "exec ./foo", :exitstatus => true
    check exitstatus.should == 126
    out.should include("fundler: not executable: ./foo")
  end

  describe "with gem binaries" do
    describe "run from a random directory" do
      before(:each) do
        install_gemfile <<-G
          gem "rack"
        G
      end

      it "works when unlocked" do
        fundle "exec 'cd #{tmp('gems')} && rackup'"
        out.should == "1.0.0"
      end

      it "works when locked" do
        fundle "lock"
        should_be_locked
        fundle "exec 'cd #{tmp('gems')} && rackup'"
        out.should == "1.0.0"
      end
    end

    describe "from gems fundled via :path" do
      before(:each) do
        build_lib "fizz", :path => home("fizz") do |s|
          s.executables = "fizz"
        end

        install_gemfile <<-G
          gem "fizz", :path => "#{File.expand_path(home("fizz"))}"
        G
      end

      it "works when unlocked" do
        fundle "exec fizz"
        out.should == "1.0"
      end

      it "works when locked" do
        fundle "lock"
        should_be_locked

        fundle "exec fizz"
        out.should == "1.0"
      end
    end

    describe "from gems fundled via :git" do
      before(:each) do
        build_git "fizz_git" do |s|
          s.executables = "fizz_git"
        end

        install_gemfile <<-G
          gem "fizz_git", :git => "#{lib_path('fizz_git-1.0')}"
        G
      end

      it "works when unlocked" do
        fundle "exec fizz_git"
        out.should == "1.0"
      end

      it "works when locked" do
        fundle "lock"
        should_be_locked
        fundle "exec fizz_git"
        out.should == "1.0"
      end
    end

    describe "from gems fundled via :git with no gemspec" do
      before(:each) do
        build_git "fizz_no_gemspec", :gemspec => false do |s|
          s.executables = "fizz_no_gemspec"
        end

        install_gemfile <<-G
          gem "fizz_no_gemspec", "1.0", :git => "#{lib_path('fizz_no_gemspec-1.0')}"
        G
      end

      it "works when unlocked" do
        fundle "exec fizz_no_gemspec"
        out.should == "1.0"
      end

      it "works when locked" do
        fundle "lock"
        should_be_locked
        fundle "exec fizz_no_gemspec"
        out.should == "1.0"
      end
    end

  end

  describe "bundling fundler" do
    before(:each) do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      fundle "install --path vendor/fundle --disable-shared-gems"
    end

    it "does not explode with --disable-shared-gems" do
      fundle "exec fundle check", :exitstatus => true
      exitstatus.should == 0
    end

    it "does not explode when starting with Fundler.setup" do
      ruby <<-R
        require "rubygems"
        require "fundler"
        Fundler.setup
        puts `fundle check`
        puts $?.exitstatus
      R

      out.should include("satisfied")
      out.should include("\n0")
    end
  end
end
