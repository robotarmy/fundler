require "spec_helper"

describe "fundle gem" do
  before :each do
    fundle 'gem test-gem'
  end

  it "generates a gem skeleton" do
    fundled_app("test-gem/test-gem.gemspec").should exist
    fundled_app("test-gem/Gemfile").should exist
    fundled_app("test-gem/Rakefile").should exist
    fundled_app("test-gem/lib/test-gem.rb").should exist
    fundled_app("test-gem/lib/test-gem/version.rb").should exist
  end

  it "starts with version 0.0.1" do
    fundled_app("test-gem/lib/test-gem/version.rb").read.should =~ /VERSION = "0.0.1"/
  end

  it "nests constants so they work" do
    fundled_app("test-gem/lib/test-gem/version.rb").read.should =~ /module Test\n  module Gem/
    fundled_app("test-gem/lib/test-gem.rb").read.should =~ /module Test\n  module Gem/
  end
end