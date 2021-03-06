require "spec_helper"

describe "fundle open" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G
  end

  it "opens the gem with BUNDLER_EDITOR as highest priority" do
    fundle "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "BUNDLER_EDITOR" => "echo fundler_editor"}
    out.should == "fundler_editor #{default_fundle_path('gems', 'rails-2.3.2')}"
  end

  it "opens the gem with VISUAL as 2nd highest priority" do
    fundle "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "BUNDLER_EDITOR" => ""}
    out.should == "visual #{default_fundle_path('gems', 'rails-2.3.2')}"
  end

  it "opens the gem with EDITOR as 3rd highest priority" do
    fundle "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "BUNDLER_EDITOR" => ""}
    out.should == "editor #{default_fundle_path('gems', 'rails-2.3.2')}"
  end

  it "complains if no EDITOR is set" do
    fundle "open rails", :env => {"EDITOR" => "", "VISUAL" => "", "BUNDLER_EDITOR" => ""}
    out.should == "To open a fundled gem, set $EDITOR or $BUNDLER_EDITOR"
  end

  it "complains if gem not in fundle" do
    fundle "open missing", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "BUNDLER_EDITOR" => ""}
    out.should match(/could not find gem 'missing'/i)
  end
end
