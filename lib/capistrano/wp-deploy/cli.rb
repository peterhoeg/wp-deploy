require 'thor'
require 'yaml'

class WpdCLI < Thor
  include Thor::Actions

  def self.source_root
    File.expand_path('../templates', __FILE__)
  end

  desc 'init [DIRECTORY]', 'Initialises the WordPress project in the given directory'
  def init(installpath = '.')
    say "wp deploy: Intalling wpdeploy in directory #{installpath}", :green

    # Check if the project needs initialising
    if Dir.exist?(installpath + '/config')
      say "wp-deploy: Looks like you've already initialised this project! If you're trying to update your configuration using the settings in your .yml files, try running `wpdeploy config` first.", :red
      exit
    end

    # Print welcome message
    say "
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Welcome to wp-deploy!

To get started, you can configure wp-deploy in one of two ways:

- Via terminal prompts (takes around 5 minutes)
- Manually enter your details into the configuration files .yml which will be
generated in the config/ directory.

If you choose to install via prompts, you can skip any prompt and enter the
details maunally later if you prefer.
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––\n\n", :green

    setup_method = ask('How would you like to configure wp-deploy?:', :blue, limited_to: %w(prompt manual))
    say "\n"

    # Create blank yaml files
    directory 'yaml', installpath + '/config'
    say "\n"

    # If the user would rather be prompted for details
    if setup_method == 'prompt'

      # Load in yaml files for populating
      databaseYaml = YAML.load_file('config/database.yml')
      settingsYaml = YAML.load_file('config/settings.yml')
      environmentsYaml = YAML.load_file('config/environments.yml')

      environments = %w(local staging production)

      # Prompt for database details
      environments.each do |env|
        say("Configure your #{env} database", :bold)
        databaseYaml[env]['host'] = ask('What hostname should we use? (usually localhost):', :blue)
        databaseYaml[env]['database'] = ask('What is the name of your database?:', :blue)
        databaseYaml[env]['username'] = ask('What username should we connect to the database with?:', :blue)
        databaseYaml[env]['password'] = ask('What is the password for this user?: ', :blue, echo: false)
        say "\n\n"
      end

      # Prompt for WordPress details
      say('Configure your WordPress settings', :bold)
      settingsYaml['wp_user'] = ask('What username do you want to log into WordPress with? (a random password will be created):', :blue)
      settingsYaml['wp_email'] = ask('What email address should be associated with your WordPress user account?:', :blue)
      settingsYaml['wp_sitename'] = ask('What is the name of your new website?:', :blue)
      settingsYaml['git_repo'] = ask('What is the URL of your git repository? (e.g. git@github.com:Mixd/wp-deploy.git):', :blue)
      settingsYaml['local_url'] = ask('What URL will you use to access your local host? (e.g. http://yoursite.dev):', :blue)
      say "\n"

      environments = %w(staging production)

      # Prompt for environment access details
      environments.each do |env|
        say("Configure your remote #{env} access", :bold)
        environmentsYaml[env]['stage_url'] = ask('What is the full URL of your remote environment? (e.g. http://www.example.com):', :blue)
        environmentsYaml[env]['server'] = ask('What is the server address? (this can be an IP or domain):', :blue)
        environmentsYaml[env]['user'] = ask('What user should we connect to this server as?:', :blue)
        environmentsYaml[env]['deploy_to'] = ask('Where should we deploy to on this server? (e.g. /var/www/vhosts/mysite.com/httpdocs):', :blue)
        say "\n"
      end

      # Write results to yaml files
      File.open(installpath + '/config/database.yml', 'w') { |f| f.write databaseYaml.to_yaml }
      File.open(installpath + '/config/settings.yml', 'w') { |f| f.write settingsYaml.to_yaml }
      File.open(installpath + '/config/environments.yml', 'w') { |f| f.write environmentsYaml.to_yaml }

      say "
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Your project is now ready to be installed.

Run `wpdeploy install` to install WordPress using the settings you
have provided.

If you ever need to update your settings after installation, just edit the .yml
files in config/ and run `wpdeploy config` to apply them.
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––", :green

    else
      say 'Your config files are now in the /config directory. Populate them at your leisure then run `wpdeploy install`.', :green
    end
  end

  desc 'install', 'Installs WordPress locally and configures wp-deploy.'
  def install
    # Check if init has been run first
    unless Dir.exist?('config')
      say 'wp-deploy: Configuration files not found. Please run `wpdeploy init` and set up your configuration files first.', :red
      exit
    end

    # Create base WordPress/Capistrano files
    say 'wp-deploy: Setting up a new wp-deploy project', :green
    directory '.', '.', exclude_pattern: /yaml/

    # Initialise new git repo
    say 'wp-deploy: Checking if we need a new git repo', :green
    system('git init') unless Dir.exist?('.git')

    # Fetch WP core submodule
    say 'wp-deploy: Cloning latest WordPress core as a submodule', :green
    system('
        git submodule add https://github.com/WordPress/WordPress.git wordpress
        cd wordpress
        git fetch --tags
        latestTag=$(git tag -l | sort -n -r -t. -k1,1 -k2,2 -k3,3 -k4,4 | sed -n 1p)
        git checkout -q $latestTag
        cd ../
        git add -A
        git commit -m "Set up wp-deploy"
    ')

    # Create wp-config.php
    config

    # Setup vars for WP install

    settings = YAML.load_file('config/settings.yml')
    siteurl = settings['local_url']
    title = settings['wp_sitename']
    user = settings['wp_user']
    email = settings['wp_email']

    # Generate a random password
    o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
    password = (0...18).map { o[rand(o.length)] }.join

    # Install WordPress
    wpinstall = run("wp core install --url='#{siteurl}' --title='#{title}' --admin_user='#{user}' --admin_password='#{password}' --admin_email='#{email}'")

    if wpinstall == false
      say_status('error', 'wp-deploy could not connect to your database. Please check your database.yml. If you are using MAMP, please refer to the wp-deploy docs for known issues.', :red)
    else
      say "
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
WordPress has now been installed locally! Here are your login details:

Username:       #{user}
Password:       #{password}
Log in at:      #{siteurl}/wordpress/wp-admin/
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––", :green

    end
  end

  desc 'config', 'Regenerate configuration files using YAML details provided.'
  def config
    # Parse required YAML
    database = YAML.load_file('config/database.yml')['local']
    stage_url = YAML.load_file('config/settings.yml')['local_url']

    # Create wp-config.php
    secret_keys = run('curl -s -k https://api.wordpress.org/secret-key/1.1/salt', capture: true)
    db_config = ERB.new(File.read('config/templates/wp-config.php.erb')).result(binding)
    File.open('wp-config.php', 'w') { |f| f.write(db_config) }

    say_status('success', 'Your database details have been updated in your wp-config.php.', :green)
  end
end
