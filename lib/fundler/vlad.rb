# Vlad task for Fundler.
#
# Just add "require 'fundler/vlad'" in your Vlad deploy.rb, and
# include the vlad:bundle:install task in your vlad:deploy task.
require 'fundler/deployment'

namespace :vlad do
  Fundler::Deployment.define_task(Rake::RemoteTask, :remote_task, :roles => :app)
end