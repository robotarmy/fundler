require 'fundler/shared_helpers'

if Fundler::SharedHelpers.in_bundle?
  require 'fundler'
  begin
    Fundler.setup
  rescue Fundler::FundlerError => e
    puts "\e[31m#{e.message}\e[0m"
    puts e.backtrace.join("\n") if ENV["DEBUG"]
    exit e.status_code
  end

  # Add fundler to the load path after disabling system gems
  fundler_lib = File.expand_path("../..", __FILE__)
  $LOAD_PATH.unshift(fundler_lib) unless $LOAD_PATH.include?(fundler_lib)
end
