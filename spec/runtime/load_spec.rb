require "spec_helper"

describe "Fundler.load" do
  before :each do
    system_gems "rack-1.0.0"
    # clear memoized method results
    # TODO: Don't reset internal ivars
    Fundler.instance_eval do
      @load = nil
      @runtime = nil
      @definition = nil
    end
  end

  describe "with a gemfile" do
    before(:each) do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "provides a list of the env dependencies" do
      Fundler.load.dependencies.should have_dep("rack", ">= 0")
    end

    it "provides a list of the resolved gems" do
      Fundler.load.gems.should have_gem("rack-1.0.0", "fundler-#{Fundler::VERSION}")
    end

    it "ignores blank BUNDLE_GEMFILEs" do
      lambda {
        ENV['BUNDLE_GEMFILE'] = ""
        Fundler.load
      }.should_not raise_error(Fundler::GemfileNotFound)
    end

  end

  describe "without a gemfile" do
    it "raises an exception if the default gemfile is not found" do
      lambda {
        Fundler.load
      }.should raise_error(Fundler::GemfileNotFound, /could not locate gemfile/i)
    end

    it "raises an exception if a specified gemfile is not found" do
      lambda {
        ENV['BUNDLE_GEMFILE'] = "omg.rb"
        Fundler.load
      }.should raise_error(Fundler::GemfileNotFound, /omg\.rb/)
    end

    it "does not find a Gemfile above the testing directory" do
      fundler_gemfile = tmp.join("../Gemfile")
      unless File.exists?(fundler_gemfile)
        FileUtils.touch(fundler_gemfile)
        @remove_fundler_gemfile = true
      end
      begin
        lambda { Fundler.load }.should raise_error(Fundler::GemfileNotFound)
      ensure
        fundler_gemfile.rmtree if @remove_fundler_gemfile
      end
    end

  end

  describe "when called twice" do
    it "doesn't try to load the runtime twice" do
      system_gems "rack-1.0.0", "activesupport-2.3.5"
      gemfile <<-G
        gem "rack"
        gem "activesupport", :group => :test
      G

      ruby <<-RUBY
        require "fundler"
        Fundler.setup :default
        Fundler.require :default
        puts RACK
        begin
          require "activesupport"
        rescue LoadError
          puts "no activesupport"
        end
      RUBY

      out.split("\n").should == ["1.0.0", "no activesupport"]
    end
  end

  describe "not hurting brittle rubygems" do
    it "does not inject #source into the generated YAML of the gem specs" do
      system_gems "activerecord-2.3.2", "activesupport-2.3.2"
      gemfile <<-G
        gem "activerecord"
      G

      Fundler.load.specs.each do |spec|
        spec.to_yaml.should_not =~ /^\s+source:/
        spec.to_yaml.should_not =~ /^\s+groups:/
      end
    end
  end

end
