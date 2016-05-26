def rsync_args(port)
  args = '-avzO'
  return "#{args} -e 'ssh -p #{port}'" if port.to_i > 0
  return args
end

namespace :uploads do

  desc "Push any changed or new files from local to remote"
  task :push do
    run_locally do
      roles(:all).each do |role|
        execute :rsync, "#{rsync_args role.port} content/uploads/ #{role.user}@#{role.hostname}:#{shared_path}/content/uploads"
      end
    end
  end

  desc "Pull any changed or new files from remote to local"
  task :pull do
    run_locally do
      roles(:all).each do |role|
        execute :rsync, "#{rsync_args role.port} #{role.user}@#{role.hostname}:#{shared_path}/content/uploads/ content/uploads"
      end
    end
  end
end
