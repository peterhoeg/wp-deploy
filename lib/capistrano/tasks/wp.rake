namespace :wp do
  task :set_permissions do
    on roles(:app) do
      execute :chmod, "666 #{shared_path}/.htaccess"
      execute :chmod, "-R 777 #{shared_path}/content/uploads"
    end
  end

  desc 'Setup WP on remote environment'
  task :setup do
    invoke 'db:confirm'
    invoke 'deploy'
    on roles(:web) do
      # Get details for WordPress config file
      secret_keys = capture('curl -s -k https://api.wordpress.org/secret-key/1.1/salt')
      stage_url = YAML.load_file('config/environments.yml')[fetch(:stage).to_s]['stage_url']
      database = YAML.load_file('config/database.yml')[fetch(:stage).to_s]

      # Create config file in remote environment
      db_config = ERB.new(File.read('config/templates/wp-config.php.erb')).result(binding)
      io = StringIO.new(db_config)
      upload! io, File.join(shared_path, 'wp-config.php')

      # Create .htaccess in remote environment
      accessfile = ERB.new(File.read('config/templates/.htaccess.erb')).result(binding)
      io = StringIO.new(accessfile)
      upload! io, File.join(shared_path, '.htaccess')

      within release_path do
        # Generate a random password
        o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
        password = (0...18).map { o[rand(o.length)] }.join

        # Get WP details from YAML
        settings = YAML.load_file('config/settings.yml')
        title = settings['wp_sitename']
        user = settings['wp_user']
        email = settings['wp_email']

        # Install WordPress
        execute :wp, "core install --url='#{stage_url}' --title='#{title}' --admin_user='#{user}' --admin_password='#{password}' --admin_email='#{email}'"

        # Set some permissions
        invoke 'wp:set_permissions'

        puts <<-MSG
        \e[32m
        =========================================================================
          WordPress has successfully been installed on remote envrionment.

          Here are your login details:

          Username:       #{user}
          Password:       #{password}
          Email address:  #{email}
          Log in at:      #{stage_url}/wordpress/wp-admin
        =========================================================================
        \e[0m
        MSG
      end
    end
  end

  namespace :core do
    desc 'Updates the WP core submodule to the latest tag'
    task :update do
      system('
      cd wordpress
      git fetch --tags
      latestTag=$(git describe --tags `git rev-list --tags --max-count=1`)
      git checkout $latestTag
      ')
      invoke 'cache:repo:purge'
      puts 'WordPress submodule is now at the latest version. You should now commit your changes.'
    end
  end
end
