source "http://rubygems.org"

# Specify your gem's dependencies in access_control.gemspec
gemspec

gem 'iconv'
gem 'rspec', '~> 1.3.0', git: 'https://bitbucket.org/aptn/rspec'

group :development do
  gem 'pry'
  gem 'pry-doc'
  gem 'pry-byebug', '~> 3.1.0'
  gem "pry-theme"
  gem 'test-unit', '1.2.3', require: false
  gem 'database_cleaner'
end

group :guard do
  gem 'guard'
  gem 'guard-rspec'
  gem 'libnotify'
  gem 'rb-inotify'
end

group :mysql do
  platform :mri do
    gem 'mysql2', "< 0.3.0"
  end

  platform :jruby do
    gem 'activerecord-jdbcmysql-adapter'
    gem 'jdbc-mysql'
  end
end
