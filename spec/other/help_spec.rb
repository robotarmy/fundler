require "spec_helper"

describe "fundle help" do
  it "complains if older versions of fundler are installed" do
    system_gems "fundler-0.8.1"

    fundle "help", :expect_err => true
    err.should == "Please remove older versions of fundler. This can be done by running `gem cleanup fundler`."
  end

  it "uses groff when available" do
    fake_groff!

    fundle "help gemfile"
    out.should == %|["-Wall", "-mtty-char", "-mandoc", "-Tascii", "#{root}/lib/fundler/man/gemfile.5"]|
  end

  it "prefixes fundle commands with fundle- when finding the groff files" do
    fake_groff!

    fundle "help install"
    out.should == %|["-Wall", "-mtty-char", "-mandoc", "-Tascii", "#{root}/lib/fundler/man/fundle-install"]|
  end

  it "simply outputs the txt file when there is no groff on the path" do
    kill_path!

    fundle "help install", :expect_err => true
    out.should =~ /BUNDLE-INSTALL/
  end

  it "still outputs the old help for commands that do not have man pages yet" do
    fundle "help check"
    out.should include("Check searches the local machine")
  end
end
