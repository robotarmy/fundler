require "spec_helper"

describe "Running bin/* commands" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  it "runs the fundled command when in the fundle" do
    fundle "install --binstubs"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    gembin "rackup"
    out.should == "1.0.0"
  end

  it "allows the location of the gem stubs to be specified" do
    fundle "install --binstubs gbin"

    fundled_app("bin").should_not exist
    fundled_app("gbin/rackup").should exist

    gembin fundled_app("gbin/rackup")
    out.should == "1.0.0"
  end

  it "allows absolute paths as a specification of where to install bin stubs" do
    fundle "install --binstubs #{tmp}/bin"

    gembin tmp("bin/rackup")
    out.should == "1.0.0"
  end

  it "runs the fundled command when out of the fundle" do
    fundle "install --binstubs"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    Dir.chdir(tmp) do
      gembin "rackup"
      out.should == "1.0.0"
    end
  end

  it "works with gems in path" do
    build_lib "rack", :path => lib_path("rack") do |s|
      s.executables = 'rackup'
    end

    gemfile <<-G
      gem "rack", :path => "#{lib_path('rack')}"
    G

    fundle "install --binstubs"

    build_gem 'rack', '2.0', :to_system => true do |s|
      s.executables = 'rackup'
    end

    gembin "rackup"
    out.should == '1.0'
  end

  it "don't fundle da bundla" do
    build_gem "fundler", Fundler::VERSION, :to_system => true do |s|
      s.executables = "fundle"
    end

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "fundler"
    G

    fundle "install --binstubs"

    fundled_app("bin/fundle").should_not exist
  end

  it "does not generate bin stubs if the option was not specified" do
    fundle "install"

    fundled_app("bin/rackup").should_not exist
  end

  it "remembers that the option was specified" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
    G

    fundle "install --binstubs"

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
      gem "rack"
    G

    fundle "install"

    fundled_app("bin/rackup").should exist
  end
end