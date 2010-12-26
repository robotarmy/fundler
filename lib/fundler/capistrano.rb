# Capistrano task for Fundler.
#
# Just add "require 'fundler/capistrano'" in your Capistrano deploy.rb, and
# Fundler will be activated after each new deployment.
require 'fundler/deployment'

Capistrano::Configuration.instance(:must_exist).load do
  after "deploy:update_code", "fundle:install"
  Fundler::Deployment.define_task(self, :task, :except => { :no_release => true })
end
