require 'erb'
require 'rubygems/dependency_installer'

module Fundler
  class Installer < Environment
    def self.install(root, definition, options = {})
      installer = new(root, definition)
      installer.run(options)
      installer
    end

    def run(options)
      if Fundler.settings[:frozen]
        @definition.ensure_equivalent_gemfile_and_lockfile
      end

      if dependencies.empty?
        Fundler.ui.warn "The Gemfile specifies no dependencies"
        return
      end

      if Fundler.default_lockfile.exist? && !options["update"]
        begin
          tmpdef = Definition.build(Fundler.default_gemfile, Fundler.default_lockfile, nil)
          local = true unless tmpdef.new_platform? || tmpdef.missing_specs.any?
        rescue FundlerError
        end
      end

      # Since we are installing, we can resolve the definition
      # using remote specs
      unless local
        options["local"] ?
          @definition.resolve_with_cache! :
          @definition.resolve_remotely!
      end

      # Ensure that BUNDLE_PATH exists
      Fundler.mkdir_p(Fundler.bundle_path) unless File.exist?(Fundler.bundle_path)

      # Must install gems in the order that the resolver provides
      # as dependencies might actually affect the installation of
      # the gem.
      specs.each do |spec|
        spec.source.fetch(spec) if spec.source.respond_to?(:fetch)

        # unless requested_specs.include?(spec)
        #   Fundler.ui.debug "  * Not in requested group; skipping."
        #   next
        # end

        begin
          old_args = Gem::Command.build_args
          Gem::Command.build_args = [Fundler.settings["build.#{spec.name}"]]
          spec.source.install(spec)
          Fundler.ui.debug "from #{spec.loaded_from} "
        ensure
          Gem::Command.build_args = old_args
        end

        Fundler.ui.info ""
        generate_fundler_executable_stubs(spec) if Fundler.settings[:bin]
        FileUtils.rm_rf(Fundler.tmp)
      end

      lock
    end

  private

    def generate_fundler_executable_stubs(spec)
      bin_path = Fundler.bin_path
      template = File.read(File.expand_path('../templates/Executable', __FILE__))
      relative_gemfile_path = Fundler.default_gemfile.relative_path_from(bin_path)
      ruby_command = Thor::Util.ruby_command

      spec.executables.each do |executable|
        next if executable == "bundle"
        File.open "#{bin_path}/#{executable}", 'w', 0755 do |f|
          f.puts ERB.new(template, nil, '-').result(binding)
        end
      end
    end
  end
end
