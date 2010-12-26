require "spec_helper"
describe "fundle cache with git" do
  it "base_name should strip private repo uris" do
    source  = Fundler::Source::Git.new("uri" => "git@github.com:fundler.git")
    source.send(:base_name).should == "fundler"
  end
end


