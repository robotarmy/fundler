require "spec_helper"

describe "fundle install with deprecated features" do
  before :each do
    in_app_root
  end

  it "reports that lib is an invalid option" do
    gemfile <<-G
      gem "rack", :lib => "rack"
    G

    fundle :install
    out.should =~ /You passed :lib as an option for gem 'rack', but it is invalid/
  end

end
