module Fundler
  class Deployment
    def self.define_task(context, task_method = :task, opts = {})
      if context.is_a?(Capistrano::Configuration)
        context_name = "capistrano"
        role_default = "{:except => {:no_release => true}}"
      else
        context_name = "vlad"
        role_default = "[:app]"
      end

      roles = context.fetch(:fundle_roles, nil)
      opts[:roles] = roles if roles

      context.send :namespace, :fundle do
        send :desc, <<-DESC
          Install the current Fundler environment. By default, gems will be \
          installed to the shared/fundle path. Gems in the development and \
          test group will not be installed. The install command is executed \
          with the --deployment and --quiet flags. If the fundle cmd cannot \
          be found then you can override the fundle_cmd variable to specifiy \
          which one it should use.

          You can override any of these defaults by setting the variables shown below.

          N.B. fundle_roles must be defined before you require 'fundler/#{context_name}' \
          in your deploy.rb file.

            set :fundle_gemfile,  "Gemfile"
            set :fundle_dir,      File.join(fetch(:shared_path), 'fundle')
            set :fundle_flags,    "--deployment --quiet"
            set :fundle_without,  [:development, :test]
            set :fundle_cmd,      "fundle" # e.g. "/opt/ruby/bin/fundle"
            set :fundle_roles,    #{role_default} # e.g. [:app, :batch]
        DESC
        send task_method, :install, opts do
          fundle_cmd     = context.fetch(:fundle_cmd, "fundle")
          fundle_flags   = context.fetch(:fundle_flags, "--deployment --quiet")
          fundle_dir     = context.fetch(:fundle_dir, File.join(context.fetch(:shared_path), 'fundle'))
          fundle_gemfile = context.fetch(:fundle_gemfile, "Gemfile")
          fundle_without = [*context.fetch(:fundle_without, [:development, :test])].compact

          args = ["--gemfile #{File.join(context.fetch(:current_release), fundle_gemfile)}"]
          args << "--path #{fundle_dir}" unless fundle_dir.to_s.empty?
          args << fundle_flags.to_s
          args << "--without #{fundle_without.join(" ")}" unless fundle_without.empty?

          run "#{fundle_cmd} install #{args.join(' ')}"
        end
      end
    end
  end
end
