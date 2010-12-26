# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'fundler/version'

Gem::Specification.new do |s|
  s.name        = "fundler"
  s.version     = Fundler::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Carl Lerche", "Yehuda Katz", "André Arko"]
  s.email       = ["carlhuda@engineyard.com"]
  s.homepage    = "http://gemfundler.com"
  s.summary     = %q{The best way to manage your application's dependencies}
  s.description = %q{Fundler manages an application's dependencies through its entire life, across many machines, systematically and repeatably}

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "fundler"

  s.add_development_dependency "ronn"
  s.add_development_dependency "rspec"

  # Man files are required because they are ignored by git
  man_files            = Dir.glob("lib/fundler/man/**/*")
  s.files              = `git ls-files`.split("\n") + man_files
  s.test_files         = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables        = %w(bundle)
  s.default_executable = "bundle"
  s.require_paths      = ["lib"]
end
