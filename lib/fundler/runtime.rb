require "digest/sha1"

module Fundler
  class Runtime < Environment
    include SharedHelpers

    def setup(*groups)
      # Has to happen first
      clean_load_path

      specs = groups.any? ? @definition.specs_for(groups) : requested_specs

      setup_environment
      cripple_rubygems(specs)

      # Activate the specs
      specs.each do |spec|
        unless spec.loaded_from
          raise GemNotFound, "#{spec.full_name} is missing. Run `fundle` to get it."
        end

        if activated_spec = Gem.loaded_specs[spec.name] and activated_spec.version != spec.version
          e = Gem::LoadError.new "You have already activated #{activated_spec.name} #{activated_spec.version}, " \
                                 "but your Gemfile requires #{spec.name} #{spec.version}. Consider using fundle exec."
          e.name = spec.name
          e.version_requirement = Gem::Requirement.new(spec.version.to_s)
          raise e
        end

        Gem.loaded_specs[spec.name] = spec
        load_paths = spec.load_paths.reject {|path| $LOAD_PATH.include?(path)}
        $LOAD_PATH.unshift(*load_paths)
      end

      lock

      self
    end

    REGEXPS = [
      /^no such file to load -- (.+)$/i,
      /^Missing \w+ (?:file\s*)?([^\s]+.rb)$/i,
      /^Missing API definition file in (.+)$/i,
      /^cannot load such file -- (.+)$/i,
    ]

    def require(*groups)
      groups.map! { |g| g.to_sym }
      groups = [:default] if groups.empty?

      @definition.dependencies.each do |dep|
        # Skip the dependency if it is not in any of the requested
        # groups
        next unless ((dep.groups & groups).any? && dep.current_platform?)

        required_file = nil

        begin
          # Loop through all the specified autorequires for the
          # dependency. If there are none, use the dependency's name
          # as the autorequire.
          Array(dep.autorequire || dep.name).each do |file|
            required_file = file
            Kernel.require file
          end
        rescue LoadError => e
          REGEXPS.find { |r| r =~ e.message }
          raise if dep.autorequire || $1 != required_file
        end
      end
    end

    def dependencies_for(*groups)
      if groups.empty?
        dependencies
      else
        dependencies.select { |d| (groups & d.groups).any? }
      end
    end

    alias gems specs

    def cache
      FileUtils.mkdir_p(cache_path)

      Fundler.ui.info "Updating .gem files in vendor/cache"
      specs.each do |spec|
        next if spec.name == 'fundler'
        spec.source.cache(spec) if spec.source.respond_to?(:cache)
      end
      prune_cache unless Fundler.settings[:no_prune]
    end

    def prune_cache
      FileUtils.mkdir_p(cache_path)

      resolve = @definition.resolve
      cached  = Dir["#{cache_path}/*.gem"]

      cached = cached.delete_if do |path|
        spec = Gem::Format.from_file_by_path(path).spec

        resolve.any? do |s|
          s.name == spec.name && s.version == spec.version && !s.source.is_a?(Fundler::Source::Git)
        end
      end

      if cached.any?
        Fundler.ui.info "Removing outdated .gem files from vendor/cache"

        cached.each do |path|
          Fundler.ui.info "  * #{File.basename(path)}"
          File.delete(path)
        end
      end
    end

  private

    def cache_path
      root.join("vendor/cache")
    end

    def setup_environment
      begin
        ENV["BUNDLE_BIN_PATH"] = Gem.bin_path("fundler", "fundle", VERSION)
      rescue Gem::GemNotFoundException
        ENV["BUNDLE_BIN_PATH"] = File.expand_path("../../../bin/fundle", __FILE__)
      end

      # Set PATH
      paths = (ENV["PATH"] || "").split(File::PATH_SEPARATOR)
      paths.unshift "#{Fundler.fundle_path}/bin"
      ENV["PATH"] = paths.uniq.join(File::PATH_SEPARATOR)

      # Set BUNDLE_GEMFILE
      ENV["BUNDLE_GEMFILE"] = default_gemfile.to_s

      # Set RUBYOPT
      rubyopt = [ENV["RUBYOPT"]].compact
      if rubyopt.empty? || rubyopt.first !~ /-rfundler\/setup/
        rubyopt.unshift "-rfundler/setup"
        rubyopt.unshift "-I#{File.expand_path('../..', __FILE__)}"
        ENV["RUBYOPT"] = rubyopt.join(' ')
      end
    end
  end
end
