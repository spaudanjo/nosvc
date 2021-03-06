source "https://rubygems.org"
source 'http://gems.github.com'

ruby '1.9.3'

gem 'rails', '3.2.13'
gem 'rake', '0.9.2.2'

# Database and data related [Putting pg to the end because of a weird bug with Lion, pg and openssl]
gem 'pg'
gem 'foreigner'
gem 'activerecord-postgresql-adapter'

gem 'catarse_paypal_express', '~> 0.0.2'
gem 'catarse_moip', '~> 0.1.1'
gem 'moip_catarse', '~> 1.0.6', require: 'moip'

gem 'maxim-sexy_pg_constraints'
gem 'dalli', '~> 2.2.1'
gem 'draper', '0.17.0'

# Frontend stuff
gem 'jquery-rails', '2.0.2'
gem 'slim'
gem 'slim-rails'

# Authentication and Authorization
gem 'omniauth', "~> 1.1.0"
gem 'omniauth-openid', '~> 1.0.1'
gem 'omniauth-twitter', '~> 0.0.12'
gem 'omniauth-facebook', '~> 1.2.0'
gem 'devise', '1.5.3'
gem 'cancan'

# Email marketing
gem 'mailchimp'

# HTML manipulation and formatting
gem 'formtastic'
gem "auto_html", '= 1.4.2'
gem 'kaminari'
gem 'rails_autolink', '~> 1.0.7'

# Uploads
gem 'carrierwave', '= 0.5.8'
gem 'rmagick'
gem 'fog'

# Other Tools
gem 'feedzirra'
gem 'validation_reflection', git: 'git://github.com/ncri/validation_reflection.git'
gem 'inherited_resources', '1.3.1'
gem 'has_scope'
gem 'spectator-validates_email', require: 'validates_email'
gem 'has_vimeo_video', '~> 0.0.5'
gem 'wirble'
gem "on_the_spot"
gem 'weekdays'
gem 'brcep'
gem "RedCloth"
gem 'unicode'
gem 'enumerate_it'
gem 'httparty', '~> 0.6.1'
gem "rack-timeout"
gem 'tumblr-api'

# Translations
gem 'http_accept_language'
gem 'routing-filter' #, :git => 'git://github.com/svenfuchs/routing-filter.git'

# Administration
gem "meta_search", "1.1.3"
gem 'rails_admin'

# Payment
gem 'activemerchant', '1.17.0', require: 'active_merchant'
gem 'httpclient', '2.2.5'
gem 'selenium-webdriver', '~> 2.31.0'
gem 'bourbon'
gem 'paypal-express', :require => 'paypal'

# Server
gem 'thin'

group :assets do
  gem 'sass-rails',   '~> 3.2.5'
  gem 'coffee-rails', '~> 3.2.2'
  gem "compass-rails", "~> 1.0.1"
  gem 'uglifier', '>= 1.0.3'
  gem 'compass-960-plugin', '~> 0.10.4'
end

group :test, :development do
  gem 'annotate'
  gem 'launchy'
  gem 'database_cleaner'
  gem 'steak', "~> 1.1.0"
  gem 'rspec-rails', "~> 2.13.0"
  gem 'rcov', '= 0.9.11'
  gem 'mocha', '0.13.3', :require => false
  gem 'shoulda-matchers'
  gem 'factory_girl_rails', '1.7.0'
  gem 'capybara', ">= 2.0.3"

end

group :development do
  gem 'mailcatcher'

  gem 'pry-rails'                                                                                           
  gem 'pry-nav'
  gem 'pry-stack_explorer'
  gem 'pry-debugger'
end

gem 'newrelic_rpm'

