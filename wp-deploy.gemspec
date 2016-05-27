# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano/wp-deploy/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'capistrano-wp-deploy'
  s.version     = WPdeploy::VERSION
  s.executables << 'wpdeploy'
  s.summary     = "wp-deploy – Easily deploy WordPress projects"
  s.description = 'A framework for deploying WordPress sites using Capistrano 3'
  s.authors     = ['Aaron Thomas', 'Luke Whitehouse']
  s.email       = ['a.thomas@mixd.co.uk', 'l.whitehouse@mixd.co.uk']
  s.files       = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  s.homepage    = 'https://github.com/Mixd/wp-deploy'
  s.license     = 'MIT'

  s.add_runtime_dependency 'capistrano', '~> 3.4'
  s.add_runtime_dependency 'thor', '~> 0.19.1'
  s.add_runtime_dependency 'wpcli', '~> 0.2.8'
end
