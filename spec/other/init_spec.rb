require "spec_helper"

describe "fundle init" do
  it "generates a Gemfile" do
    fundle :init
    fundled_app("Gemfile").should exist
  end

  it "does not change existing Gemfiles" do
    gemfile <<-G
      gem "rails"
    G

    lambda {
      fundle :init
    }.should_not change { File.read(fundled_app("Gemfile")) }
  end

  it "should generate from an existing gemspec" do
    spec_file = tmp.join('test.gemspec')
    File.open(spec_file, 'w') do |file|
      file << <<-S
        Gem::Specification.new do |s|
        s.name = 'test'
        s.add_dependency 'rack', '= 1.0.1'
        s.add_development_dependency 'rspec', '1.2'
        end
      S
    end

    fundle :init, :gemspec => spec_file

    gemfile = fundled_app("Gemfile").read
    gemfile.should =~ /source :gemcutter/
    check gemfile.scan(/gem "rack", "= 1.0.1"/).size.should == 1
    check gemfile.scan(/gem "rspec", "= 1.2"/).size.should == 1
    check gemfile.scan(/group :development/).size.should == 1
  end

end