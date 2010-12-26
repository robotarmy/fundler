require 'rbconfig'
require 'fileutils'
require 'pathname'
require 'yaml'
require 'fundler/rubygems_ext'
require 'fundler/version'

module Fundler
  ORIGINAL_ENV = ENV.to_hash

  autoload :Definition,          'fundler/definition'
  autoload :Dependency,          'fundler/dependency'
  autoload :Dsl,                 'fundler/dsl'
  autoload :Environment,         'fundler/environment'
  autoload :GemHelper,           'fundler/gem_helper'
  autoload :Graph,               'fundler/graph'
  autoload :Index,               'fundler/index'
  autoload :Installer,           'fundler/installer'
  autoload :LazySpecification,   'fundler/lazy_specification'
  autoload :LockfileParser,      'fundler/lockfile_parser'
  autoload :RemoteSpecification, 'fundler/remote_specification'
  autoload :Resolver,            'fundler/resolver'
  autoload :Runtime,             'fundler/runtime'
  autoload :Settings,            'fundler/settings'
  autoload :SharedHelpers,       'fundler/shared_helpers'
  autoload :SpecSet,             'fundler/spec_set'
  autoload :Source,              'fundler/source'
  autoload :Specification,       'fundler/shared_helpers'
  autoload :UI,                  'fundler/ui'

  class FundlerError < StandardError
    def self.status_code(code = nil)
      define_method(:status_code) { code }
    end
  end

  class GemfileNotFound  < FundlerError; status_code(10) ; end
  class GemNotFound      < FundlerError; status_code(7)  ; end
  class GemfileError     < FundlerError; status_code(4)  ; end
  class PathError        < FundlerError; status_code(13) ; end
  class GitError         < FundlerError; status_code(11) ; end
  class DeprecatedError  < FundlerError; status_code(12) ; end
  class GemspecError     < FundlerError; status_code(14) ; end
  class DslError         < FundlerError; status_code(15) ; end
  class ProductionError  < FundlerError; status_code(16) ; end
  class InvalidOption    < DslError                      ; end


  WINDOWS = RbConfig::CONFIG["host_os"] =~ %r!(msdos|mswin|djgpp|mingw)!
  FREEBSD = RbConfig::CONFIG["host_os"] =~ /bsd/
  NULL    = WINDOWS ? "NUL" : "/dev/null"

  # Internal errors, should be rescued
  class VersionConflict  < FundlerError
    attr_reader :conflicts

    def initialize(conflicts, msg = nil)
      super(msg)
      @conflicts = conflicts
    end

    status_code(6)
  end

  class InvalidSpecSet < StandardError; end

  class << self
    attr_writer :ui, :fundle_path

    def configure
      @configured ||= begin
        configure_gem_home_and_path
        true
      end
    end

    def ui
      @ui ||= UI.new
    end

    def fundle_path
      # STDERR.puts settings.path
      @fundle_path ||= Pathname.new(settings.path).expand_path(root)
    end

    def bin_path
      @bin_path ||= begin
        path = settings[:bin] || "bin"
        path = Pathname.new(path).expand_path(root)
        FileUtils.mkdir_p(path)
        Pathname.new(path).expand_path
      end
    end

    def setup(*groups)
      return @setup if defined?(@setup) && @setup

      if groups.empty?
        # Load all groups, but only once
        @setup = load.setup
      else
        # Figure out which groups haven't been loaded yet
        unloaded = groups - (@completed_groups || [])
        # Record groups that are now loaded
        @completed_groups = groups | (@completed_groups || [])
        # Load any groups that are not yet loaded
        unloaded.any? ? load.setup(*unloaded) : load
      end
    end

    def require(*groups)
      setup(*groups).require(*groups)
    end

    def load
      @load ||= Runtime.new(root, definition)
    end

    def environment
      Fundler::Environment.new(root, definition)
    end

    def definition(unlock = nil)
      @definition = nil if unlock
      @definition ||= begin
        configure
        upgrade_lockfile
        Definition.build(default_gemfile, default_lockfile, unlock)
      end
    end

    def ruby_scope
      "#{Gem.ruby_engine}/#{Gem::ConfigMap[:ruby_version]}"
    end

    def user_fundle_path
      Pathname.new(Gem.user_home).join(".fundler")
    end

    def home
      fundle_path.join("fundler")
    end

    def install_path
      home.join("gems")
    end

    def specs_path
      fundle_path.join("specifications")
    end

    def cache
      fundle_path.join("cache/fundler")
    end

    def root
      default_gemfile.dirname.expand_path
    end

    def app_config_path
      ENV['BUNDLE_APP_CONFIG'] ?
        Pathname.new(ENV['BUNDLE_APP_CONFIG']).expand_path(root) :
        root.join('.fundle')
    end

    def app_cache
      root.join("vendor/cache")
    end

    def tmp
      user_fundle_path.join("tmp", Process.pid.to_s)
    end

    def settings
      @settings ||= Settings.new(app_config_path)
    end

    def with_clean_env
      fundled_env = ENV.to_hash
      ENV.replace(ORIGINAL_ENV)
      yield
    ensure
      ENV.replace(fundled_env.to_hash)
    end

    def default_gemfile
      SharedHelpers.default_gemfile
    end

    def default_lockfile
      SharedHelpers.default_lockfile
    end

    def requires_sudo?
      return @requires_sudo if @checked_for_sudo

      path = fundle_path
      path = path.parent until path.exist?
      sudo_present = !(`which sudo` rescue '').empty?

      @checked_for_sudo = true
      @requires_sudo = settings.allow_sudo? && !File.writable?(path) && sudo_present
    end

    def mkdir_p(path)
      if requires_sudo?
        sudo "mkdir -p '#{path}'" unless File.exist?(path)
      else
        FileUtils.mkdir_p(path)
      end
    end

    def sudo(str)
      `sudo -p 'Enter your password to install the fundled RubyGems to your system: ' #{str}`
    end

    def read_file(file)
      File.open(file, "rb") { |f| f.read }
    end

    def load_gemspec(file)
      path = Pathname.new(file)
      # Eval the gemspec from its parent directory
      Dir.chdir(path.dirname.to_s) do
        begin
          Gem::Specification.from_yaml(path.basename.to_s)
          # Raises ArgumentError if the file is not valid YAML
        rescue ArgumentError, SyntaxError, Gem::EndOfYAMLException, Gem::Exception
          begin
            eval(File.read(path.basename.to_s), TOPLEVEL_BINDING, path.expand_path.to_s)
          rescue LoadError => e
            original_line = e.backtrace.find { |line| line.include?(path.to_s) }
            msg  = "There was a LoadError while evaluating #{path.basename}:\n  #{e.message}"
            msg << " from\n  #{original_line}" if original_line
            msg << "\n"

            if RUBY_VERSION >= "1.9.0"
              msg << "\nDoes it try to require a relative path? That doesn't work in Ruby 1.9."
            end

            raise GemspecError, msg
          end
        end
      end
    end

  private

    def configure_gem_home_and_path
      if settings[:disable_shared_gems]
        ENV['GEM_PATH'] = ''
        ENV['GEM_HOME'] = File.expand_path(fundle_path, root)
      elsif Gem.dir != fundle_path.to_s
        paths = [Gem.dir, Gem.path].flatten.compact.uniq.reject{|p| p.empty? }
        ENV["GEM_PATH"] = paths.join(File::PATH_SEPARATOR)
        ENV["GEM_HOME"] = fundle_path.to_s
      end

      FileUtils.mkdir_p fundle_path.to_s
      Gem.clear_paths
    end

    def upgrade_lockfile
      lockfile = default_lockfile
      if lockfile.exist? && lockfile.read(3) == "---"
        Fundler.ui.warn "Detected Gemfile.lock generated by 0.9, deleting..."
        lockfile.rmtree
      end
    end

  end
end
