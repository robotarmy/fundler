require "spec_helper"

describe "fundle cache" do
  describe "with path sources" do
    it "is silent when the path is within the fundle" do
      build_lib "foo", :path => fundled_app("lib/foo")

      install_gemfile <<-G
        gem "foo", :path => '#{fundled_app("lib/foo")}'
      G

      fundle "cache"
      out.should == "Updating .gem files in vendor/cache"
    end

    it "warns when the path is outside of the fundle" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      fundle "cache"
      out.should include("foo at `#{lib_path("foo-1.0")}` will not be cached")
    end
  end
end
